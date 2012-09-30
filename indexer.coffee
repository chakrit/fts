
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

      # NOTE: Real-world tests indicate that having huge arrays are not
      # very efficient in v8, for example we will hit this issue:
      #
      #     http://code.google.com/p/v8/issues/detail?id=2131
      #
      # if we have `indexes = []` and was doing `push()/pop()` instead
      # of just using the hash we have here since for some string
      # the number of items could easily sky rocket to more than 30k+
      # TODO: Elimite the need to buffer altogether. Possible?
      indexes = { }

      include = (word, score) ->
        return if indexes[word] and (indexes[word] > score)
        indexes[word] = score

      # TODO: Allow configuration of scores?
      for item in items
        # add each word to the index
        # [1000..800] by -50 for each word
        # first word > last word
        score = 1100
        words = vars.splitWords(item)
        for word in words
          score -= 100 if score > 800
          include word, score

        # add typo variation of the words with lower score
        # [600..400] by -50 word and -5 for typo
        score = 650
        for word in words
          score -= 50 if score > 400
          typoScore = score

          typos = vars.permuteTypos word, @degree.typos
          for typo in typos
            typoScore -= 5 if typoScore > 400
            include typo, typoScore

        # add multi-words variations to index (useful for Thai searches)
        # [800..600] by -50 permutation
        # first permutation > last permutation
        score = 850
        perms = vars.permuteWords words, @degree.words
        for perm in perms
          score -= 50 if score > 600
          include perm, score

        # also account for typos of permuted words
        # [400..200] by -50 perm and -5 for typo
        score = 450
        for perm in perms
          score -= 50 if score > 200
          typoScore = score

          typos = vars.permuteTypos perm, @degree.typos
          for typo in typos
            typoScore -= 5 if typoScore > 200
            include typo, typoScore

      addOne = (e) =>
        return cb(e) if e?

        # enumerator trick to get one key from index
        firstKey = null
        for key in indexes
          firstKey = key
          break

        return cb() if !firstKey? # no more key

        score = indexes[firstKey]
        delete indexes[firstKey]

        @addKey id, firstKey, score, addOne

      addOne()

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

