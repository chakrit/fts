
# indexer - Index content into redis
module.exports = do ->

  _ = require 'underscore'
  a = require 'async'
  assert = require 'assert'
  log = console.log
  vars = require './variations'

  ensureSetup = ->
    assert @client, 'client not set, please use() a client first'
    assert @prefix, 'prefix not set, possible invalid use() call?'

  # TODO: Ability to
  return class Indexer
    constructor: ->
      @client = null
      @prefix = null
      @degree =
        words: 3 # should match variations.permuteWords default
        typos: 5 # should match variations.permtueTypos default

    use: (prefix, client) =>
      if !client? and typeof prefix == 'object'
        client = prefix
        prefix = 'fts'

      assert client, 'client argument is required'
      @prefix = prefix
      @client = client

    addKey: (id, key, weight, cb) =>
      ensureSetup.call(this)
      assert id, 'id argument required'
      assert key, 'key argument required'
      assert weight, 'weight argument required'

      weight = parseInt(weight, 10)
      assert !isNaN(weight), 'weight argument must be a number'

      key = vars.normalizeWords(key)

      # TODO: Also add to reverse id-keys index lookup so we can do
      #   removeAll(id) regardless of key
      @client.zadd "#{@prefix}:#{key}", weight, id, cb

    removeKey: (id, key, cb) =>
      ensureSetup.call(this)
      assert id, 'id argument required'
      assert key, 'key argument required'

      @client.zrem "#{@prefix}:#{key}", id, cb

    index: (id, items, cb) =>
      ensureSetup.call(this)
      assert id, 'id argument required'
      assert items, 'items argument required'

      # overloads/optionals
      items = [items] if typeof items != 'array'
      cb ?= ->

      # callback generation helper
      # NOTE: We always add keys in the order of decreasing score
      #   so duplicate keys should not pose problems as we want
      #   key with higher score to remain as-is and not overridden
      #   by lower score key adds (which is the behavior of zadd anyway)
      newTask = (word, score) =>
        (cb) => @addKey id, word, score, cb

      # TODO: Allow configuration of scores?
      processTypos = (word, score, cb) =>
        typos = vars.permuteTypos word, @degree.typos

        tasks = for typo in typos
          score -= 5 if score > 200
          newTask typo, score

        return a.series(tasks, cb)

      processPerms = (words, cb) =>
        score = 850
        perms = vars.permuteWords words, @degree.words

        tasks = for perm in perms
          score -= 50 if score > 600
          newTask perm, score

        score = 450
        tasks.push.apply tasks,
          for perm in perms
            score -= 50 if score > 200
            do (perm, score) ->
              (cb) -> processTypos(perm, score, cb)

        return a.series(tasks, cb)

      processItem = (item, cb) =>
        score = 1100
        words = vars.splitWords(item)

        tasks = for word in words
          score -= 50 if score > 400
          newTask word, score

        score = 650
        tasks.push.apply tasks,
          for word in words
            score -= 50 if score > 400
            do (word, score) ->
              (cb) -> processTypos(word, score, cb)

        tasks.push (cb) -> processPerms(words, cb)
        return a.series(tasks, cb)

      # execute the tasks
      tasks = for item in items
        (cb) -> processItem(item, cb)

      a.series tasks, cb

    clear: (cb) =>
      ensureSetup.call(this)
      @client.keys "#{@prefix}:*", (e, keys) =>
        return cb() if keys.length == 0
        @client.del keys, cb

    query: (query, cb) =>
      ensureSetup.call(this)
      assert query, 'query argument is required'
      assert cb, 'callback argument is required'
      # strip spaces from query and normalize and just look up the word
      # from redis usin ZREVRANGE

      # TODO: good idea / better approach ?
      query = vars.splitWords(query).join('')
      @client.zrevrange "#{@prefix}:#{query}", 0, -1, cb

