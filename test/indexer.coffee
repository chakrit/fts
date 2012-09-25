
# test/indexer - Test the indexer
do ->

  _ = require 'underscore'
  a = require 'async'
  redis = require 'redis'
  expect = require('chai').expect

  # public method list for templated checks
  methods = ['addKey', 'removeKey', 'index', 'clear', 'query']

  # augmented clients for testing
  getClient = ->
    client = redis.createClient()
    client.methodsCalled = []

    # track calls to some methods
    for method in ['keys', 'zadd', 'del', 'zrem']
      do (method) ->
        origMethod = client[method]
        client[method] = ->
          client.methodsCalled.push method.toUpperCase()
          origMethod.apply this, arguments

    _.bindAll(client)
    return client

  # tests
  describe 'Indexer module', ->
    before -> @Indexer = require '../indexer'
    after -> delete @Indexer

    it 'should exports the Indexer class itself', ->
      expect(@Indexer).to.be.a('function')

    describe 'class instance', ->
      before -> @indexer = new @Indexer
      after -> delete @indexer

      describe 'use()', ->
        before -> @use = @indexer.use
        after -> delete @use

        it 'should be exported', -> expect(@use).to.be.ok

        it 'should throw for falsy input', ->
          expect(=> @use()).to.throw(/client/)
          expect(=> @use null).to.throw(/client/)

        it 'should throw if called with good prefix but falsy client', ->
          expect(=> @use 'fts').to.throw(/client/)
          expect(=> @use 'fts', null).to.throw(/client/)

        it 'should not throw if only the client is passed', (done) ->
          @use getClient() # expect to not throw
          process.nextTick =>
            @indexer.client.quit()
            delete @indexer.client
            delete @indexer.prefix
            done()

        describe 'given proper client', ->
          before -> @indexer.use (@client = getClient())
          after ->
            delete @indexer.client
            @client.quit()
            delete @client

          it 'should cause client property to be set to input', ->
            expect(@indexer.client).to.eql(@client)

          it 'should cause prefix property to be set to default value', ->
            expect(@indexer.prefix).to.be.a('string').and.ok

        describe 'given proper prefix and client', ->
          before -> @indexer.use (@prefix = 'fts'), (@client = getClient())
          after ->
            delete @indexer.client
            delete @prefix
            @client.quit()
            delete @client

          it 'should cause client property to be set to input', ->
            expect(@indexer.client).to.eql(@client)

          it 'should cause prefix property to be set to input', ->
            expect(@indexer.prefix).to.eql(@prefix)

      for method in methods
        do (method) ->
          describe "method #{method}()", ->
            it 'should be exported', ->
              expect(@indexer).to.have.property(method)
                .that.is.a('function')

            it 'should throws if invoked without a client set', ->
              expect(=> @indexer[method]()).to.throw(/client/)

      describe 'with a client set', ->
        before -> @indexer.use (@prefix = 'fts'), (@client = getClient())
        after ->
          delete @indexer.client
          delete @indexer.prefix
          delete @prefix
          @client.quit()
          delete @client

        describe 'addKey()', ->
          # TODO: Test string normalize usage
          before -> @addKey = @indexer.addKey
          after (done) ->
            delete @addKey
            @indexer.clear done

          it 'should throws if id argument is falsy', ->
            expect(=> @addKey()).to.throw(/id/)

          it 'should throws if key argument is falsy', ->
            expect(=> @addKey(123)).to.throw(/key/)

          it 'should throws if weight argument is falsy', ->
            expect(=> @addKey(123, 'testKey')).to.throw(/weight/)

          it 'should throws if weight argument not a number', ->
            expect(=> @addKey(123, 'testKey', 'blah')).to.throw(/weight/)

          describe 'calls with proper arguments', ->
            after (done) -> @indexer.clear(done)

            it 'should calls callback when finish', (done) ->
              @timeout 100
              @addKey 123, 'testKey', 100, done

            it 'should adds index key to redis', (done) ->
              @timeout 100
              @addKey 123, 'addKeyToRedis', 100, (e) =>
                return done(e) if e?
                expect(@client.methodsCalled).to.include('ZADD')
                done()

        describe 'removeKey()', ->
          before -> @removeKey = @indexer.removeKey
          after -> delete @removeKey

          it 'should throws if id argument is falsy', ->
            expect(=> @removeKey()).to.throw(/id/)

          it 'should throws if key argument is falsy', ->
            expect(=> @removeKey(123)).to.throw(/key/)

          it 'should removes index from redis', (done) ->
            @timeout 100
            @removeKey 123, 'key', (e) =>
              return done(e) if e?
              expect(@client.methodsCalled).to.include('ZREM')
              done()

        describe 'index()', ->
          before -> @index = @indexer.index
          after (done) ->
            delete @index
            @indexer.clear done

          it 'should throws if id argument is falsy', ->
            expect(=> @index()).to.throw(/id/)

          it 'should throws if items argument is falsy', ->
            expect(=> @index(123)).to.throw(/items/)

          it 'should not throws if callback not provided', ->
            @index 123, ['item']

          it 'should not throws if items argument is not an array', ->
            @index 123, 'item', ->

          # TODO: More fine-grained tests for index()
          #   possibly by moving the scoring logic outside of indexer module
          it 'should add items to redis', (done) ->
            @timeout 100
            @index 123, 'item', (e) =>
              return done(e) if e?
              expect(@client.methodsCalled).to.include('ZADD')
              done()

        describe 'clear()', ->
          before -> @clear = @indexer.clear
          after -> delete @clear

          it 'should calls callback when finish', (done) ->
            @timeout 100
            @clear done

          it 'should removes index from redis', (done) ->
            @timeout 100
            @clear (e) =>
              return done(e) if e?
              expect(@client.methodsCalled).to.include('KEYS').and.include('DEL')
              done()

        describe 'query()', ->
          before -> @query = @indexer.query
          after -> delete @query

          it 'should throws if query argument is falsy', ->
            expect(=> @query()).to.throw(/query/)

          it 'should throws if callback argument is falsy', ->
            expect(=> @query('search')).to.throw(/callback/)

          it 'should calls callback when finish', (done) ->
            @timeout 100
            @query 'test', done

          describe 'after adding a few items to index with the same key', ->
            before (done) ->
              steps = []
              steps.push (cb) => @indexer.addKey(888, 'search', 90, cb)
              steps.push (cb) => @indexer.addKey(999, 'search', 80, cb)
              steps.push (cb) => @indexer.addKey(777, 'search', 100, cb)
              a.parallel steps, done

            after (done) -> @indexer.clear done

            # TODO: More detailed tests for query()
            it 'query()-ing the search key should returns the added items in weighted order', (done) ->
              @timeout 100
              @query 'search', (e, results) =>
                results = _(results).map (item) -> parseInt(item, 10)
                expect(results).to.eql([777, 888, 999])
                done()

