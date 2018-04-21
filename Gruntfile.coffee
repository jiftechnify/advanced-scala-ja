#global module:false

"use strict"

ebook = require 'underscore-ebook-template-ja'

module.exports = (grunt) ->
  ebook(grunt, {
    dir: {
      # lib      : "src/build"
      page     : "target/pages"
      template : "src/templates"
    }
  })
  return
