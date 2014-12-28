{Disposable, CompositeDisposable} = require 'event-kit'
WorkspaceView = require 'atom'
CursorTools = require './cursor-tools'
Mark = require './mark'
EmacsState = require './emacs-state'

horizontalSpaceRange = (cursor) ->
  cursorTools = new CursorTools(cursor)
  cursorTools.skipCharactersBackward(' \t')
  start = cursor.getBufferPosition()
  cursorTools.skipCharactersForward(' \t')
  end = cursor.getBufferPosition()
  [start, end]

endLineIfNecessary = (cursor) ->
  row = cursor.getBufferPosition().row
  editor = cursor.editor
  if row == editor.getLineCount() - 1
    length = cursor.getCurrentBufferLine().length
    editor.setTextInBufferRange([[row, length], [row, length]], "\n")

deactivateCursors = (editor) ->
  for cursor in editor.getCursors()
    Mark.for(cursor).deactivate()

module.exports =
  Mark: Mark

  activate: ->
    console.log("emacs-keybind:activate")
    @disposables = new CompositeDisposable
    @disposables.add atom.workspace.observeTextEditors (editor) =>
      return if editor.mini
      element = atom.views.getView(editor)
      console.log("editorView")
      emacsState = new EmacsState(element)
      @disposables.add new Disposable =>
        emacsState.destroy()

  deactivate: ->
    console.log("emacs-keybind:deactivate")
    @disposables.dispose()
