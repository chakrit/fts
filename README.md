
# NODE-FTS

NODE-FTS is a full-text-search engine that tries to be:

* fast - using pre-filled redis zsets, searching is one ZREVRANGE command
* fuzzy - using some basic pre-computation
* unicode - using [node-stringprep](https://github.com/astro/node-stringprep) to normalize strings and
  [icu-wordsplit](https://github.com/chakrit/node-icu-wordsplit) for unicode word split

I had enough with all the search modules out there not having a hint of international characters
support in their implementation so I decided to just write one. If atleast to get other module
authors to pay more attention to people who don't speak English as their native language.

As I'm just using this for a few of my low-traffic personal side projects,
I will definitely need your help to submit enhancements and fix whatever bugs you may find.

If you don't like CoffeeScript, feel free to send me patches in pure JS, I'll happily convert it
for you.

## Install

Install with:

    npm install fts --save

and use with:

    var fts = require('fts')
      , doc =
        { id: 123
        , title: 'Hello World'
        , keywords: 'this, should, be, searchable, as, well' };

    fts.use(require('redis').createClient());

    fts.index(doc.id, [doc.title, doc.keywords], function(e) {

      fts.query('searchable', function(e, ids) {
        // ids == ['123']
      });

      fts.query('wrld', function(e, ids) {
        // ids == ['123']
      });

    });


### libicu dependency

FTS uses [node-stringprep](https://github.com/astro/node-stringprep) and
[icu-wordsplit](https://github.com/chakrit/node-icu-wordsplit) for unicode support. This means
that you will need to have a working libicu binaries installed on your machine. Depending on where you're developing node.js one of the following command will install a
working copy of libicu binaries and data files into your system:

    # ubuntu and debian-based systems
    apt-get install libicu-dev

    # gentoo
    emerge icu

    # os x
    port install icu +devel                 # with macports
    brew install icu4c && brew link icu4c   # homebrew

### How does it work?

Index in `fts` is actually a list of pre-sorted results for possible search keywords.
That is, when a new document is added, `fts` tries to build as many search keywords as possible
from it, give them weights, and add those to the "results list" for the keyword ready to be retrieved
on search.

When `index` is called, fts does the following:

1. Split up all the words
2. Index each word -
   Prefixes are weighted more than suffixes to makes searching for document titles and exact matches
   more effective.
3. Index "typo" variations for each word -
   For example "bngkok" for "Bangkok" is added with a less weight.
4. Index concatenated words subset for the entire string -
   This is required to effectively search in some language such as Thai where
   there are many ways to split a word (e.g. ตากลม => ตา | กลม or ตาก | ลม)
5. Index "typo" variations for the each concatenated word

## Main API

#### indexer.use( [prefix], redis-client )

Setup the indexer to use the specified `prefix` and `redis-client`.
You must call this function before using any of the fts module functionality.

* `prefix` - Prefix to use for all redis keys used by FTS.
* `redis-client` - The redis client to use. Any object with interface compatible with the de facto
  [redis module](https://github.com/mranney/node_redis) is fine.

#### indexer.index( id, items, callback )

Add one or more `items` to the index with identifier `id` and then calls `callback`.

* `id` - the document identifier which will be returned on queries
* `items` - Content string or array of strings to index
* `callback` - Standard callback with one error

#### indexer.clear( callback )

Removes all entries from the index effectively resetting it to initial state.

#### indexer.query( query, callback )

Queries the index using the string `query`.

* `query` - The string to search for. Spaces don't matter.
* `callback` - Callback function with signature `function(e, ids) { }`
  where `ids` is an array of document `ids` that matches the supplied query.

## Lower-level API

These APIs are provided in case you need more fine-grained control of the indexes
but should not need to to be used in most cases.

#### indexer.degree.words = 3

Get/set the degree to which fts will permute words. Defaults to 3.

Example: Permuting `"quick brown fox"` with degree 2 gives `["quickbrown", "brownfox"]`
querying with `"brownfox"` will returns the original string.

Higher degree enables broader search term matches but will require more memory
and CPU during `index()` calls.

#### indexer.degree.typos = 5

Get/set the degree to which fts will permute typos. Defaults to 5.

Example: Permuting `"search"` with degree 2 gives 22 results including `"serc"` and `"srch"`
querying with any 2 letters missing from the string will match the document.

Higher degree enables broader search term matches but will require more memory
and CPU during `index()` calls.

#### indexer.addKey( id, key, weight, callback )

Adds `id` to search key `key` with weight `weight` and then calls `callback` (optional).

* `id` - document identifier
* `key` - search key to add the document to, this will be normalized.
* `weight` - weight to give to this document for this particular search key.

#### indexer.removeKey( id, key, callback )

Removes `id` from the search key `key` regardless of weight.

* `id` - document identifier
* `key` - search key to add the document to, this will be normalized.

## License

BSD

## TODO / CONTRIBUTE

* Redis ZSETs can actually be replicated pretty easily using other kinds of databases such as MongoDB or Sqlite3
  so a different kind of backend store would probably benefits a lot of people.

* Reverse lookup (i.e. which search terms contains the document id)

* Ability to remove a document from the index.

* Search quality tests and/or more tests in general. I want this module to be rock solid.

