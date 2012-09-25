
// index.js - Module entrypoint and coffe-script loader for fts
require('coffee-script')
module.exports = new (require('./indexer.coffee'))();

