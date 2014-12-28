_ = require 'underscore-plus'
{Point, Range} = require 'atom'
{Emitter, Disposable, CompositeDisposable} = require 'event-kit'
Mark = require './mark'

module.exports =
class EmacsState
  constructor: (@editorElement) ->
    @emitter = new Emitter
    @subscriptions = new CompositeDisposable
    @editor = @editorElement.getModel()

    @editorElement.classList.add("emacs-keybind")
    @setupCommands()

  destroy: ->
    console.log("emacs-state:destroy")
    @subscriptions.dispose()
    @editorElement.classList.remove("emacs-keybind")

  setupCommands: ->
    @registerCommands
      "upcase-region": (e) => @upcaseRegion(e)
      "downcase-region": (e) => @downcaseRegion(e)
      "open-line": (e) => @openLine(e)
      "transpose-chars": (e) => @transposeChars(e)
      "transpose-words": (e) => @transposeWords(e)
      "transpose-lines": (e) => @transposeLines(e)
      "mark-whole-buffer": (e) => @markWholeBuffer(e)
      "set-mark": (e) => @setMark(e)
      "exchange-point-and-mark": (e) => @exchangePointAndMark(e)
      "copy": (e) => @copy(e)
      "forward-char": (e) => @forwardChar(e)
      "backward-char": (e) => @backwardChar(e)
      "forward-word": (e) => @forwardWord(e)
      "kill-word": (e) => @killWord(e)
      "next-line": (e) => @nextLine(e)
      "previous-line": (e) => @previousLine(e)
      "beginning-of-buffer": (e) => @beginningOfBuffer(e)
      "end-of-buffer": (e) => @endOfBuffer(e)
      "scroll-up": (e) => @scrollUp(e)
      "scroll-down": (e) => @scrollDown(e)
      "backward-paragraph": (e) => @backwardParagraph(e)
      "forward-paragraph": (e) => @forwardParagraph(e)
      "backward-word": (e) => @backwardWord(e)
      "backward-kill-word": (e) => @backwardKillWord(e)
      "just-one-space": (e) => @justOneSpace(e)
      "delete-horizontal-space": (e) => @deleteHorizontalSpace(e)
      "recenter-top-bottom": (e) => @recenterTopBottom(e)
      #"core:cancel": (e) => @keyboardQuit(e)
      #'core:cancel': (e) => @cancel(e)


  # Private: Register multiple command handlers via an {Object} that maps
  # command names to command handler functions.
  #
  # Prefixes the given command names with 'emacs-keybind:' to reduce redundancy in
  # the provided object.
  registerCommands: (commands) ->
    for commandName, fn of commands
      do (fn) =>
        @subscriptions.add(atom.commands.add(@editorElement, "emacs-keybind:#{commandName}", fn))

  upcaseRegion: (event) ->
    @editor.upperCase()

  downcaseRegion: (event) ->
    @editor.lowerCase()

  openLine: (event) ->
    @editor.insertNewline()
    @editor.moveCursorUp()

  transposeChars: (event) ->
    @editor.transpose()
    @editor.moveCursorRight()

  transposeWords: (event) ->
    @editor.transact =>
      for cursor in @editor.getCursors()
        cursorTools = new CursorTools(cursor)
        cursorTools.skipNonWordCharactersBackward()

        word1 = cursorTools.extractWord()
        word1Pos = cursor.getBufferPosition()
        cursorTools.skipNonWordCharactersForward()
        if @editor.getEofBufferPosition().isEqual(cursor.getBufferPosition())
          # No second word - put the first word back.
          @editor.setTextInBufferRange([word1Pos, word1Pos], word1)
          cursorTools.skipNonWordCharactersBackward()
        else
          word2 = cursorTools.extractWord()
          word2Pos = cursor.getBufferPosition()
          @editor.setTextInBufferRange([word2Pos, word2Pos], word1)
          @editor.setTextInBufferRange([word1Pos, word1Pos], word2)
        cursor.setBufferPosition(cursor.getBufferPosition())

  transposeLines: (event) ->
    cursor = @editor.getCursor()
    row = cursor.getBufferRow()

    @editor.transact =>
      if row == 0
        endLineIfNecessary(cursor)
        cursor.moveDown()
        row += 1
      endLineIfNecessary(cursor)

      text = @editor.getTextInBufferRange([[row, 0], [row + 1, 0]])
      @editor.deleteLine(row)
      @editor.setTextInBufferRange([[row - 1, 0], [row - 1, 0]], text)

  markWholeBuffer: (event) ->
    @editor.selectAll()

  setMark: (event) ->
    for cursor in @editor.getCursors()
      Mark.for(cursor).set().activate()

  keyboardQuit: (event) ->
    deactivateCursors(@editor)

  exchangePointAndMark: (event) ->
    @editor.moveCursors (cursor) ->
      Mark.for(cursor).exchange()

  copy: (event) ->
    @editor.copySelectedText()
    deactivateCursors(@editor)

  hasWorkspaceView: () ->
    if atom.workspaceView.find('.fuzzy-finder').view() or
       atom.workspaceView.find('.command-palette').view()
      true
    else
      false

  forwardChar: (event) ->
    @editor.moveCursors (cursor) ->
      cursor.moveRight()

  backwardChar: (event) ->
    @editor.moveCursors (cursor) ->
      cursor.moveLeft()

  forwardWord: (event) ->
    @editor.moveCursors (cursor) ->
      tools = new CursorTools(cursor)
      tools.skipNonWordCharactersForward()
      tools.skipWordCharactersForward()

  backwardWord: (event) ->
    @editor.moveCursors (cursor) ->
      tools = new CursorTools(cursor)
      tools.skipNonWordCharactersBackward()
      tools.skipWordCharactersBackward()

  nextLine: (event) ->
    @editor.moveCursors (cursor) ->
      cursor.moveDown()

  previousLine: (event) ->
    @editor.moveCursors (cursor) ->
      cursor.moveUp()

  scrollUp: (event) ->
    firstRow = @editorView.getFirstVisibleScreenRow()
    lastRow = @editorView.getLastVisibleScreenRow()
    currentRow = @editor.cursors[0].getBufferRow()
    rowCount = (lastRow - firstRow) - (currentRow - firstRow)

    @editorView.scrollToBufferPosition([lastRow * 2, 0])
    @editor.moveCursorDown(rowCount)

  scrollDown: (event) ->
    firstRow = @editorView.getFirstVisibleScreenRow()
    lastRow = @editorView.getLastVisibleScreenRow()
    currentRow = @editor.cursors[0].getBufferRow()
    rowCount = (lastRow - firstRow) - (lastRow - currentRow)

    @editorView.scrollToBufferPosition([Math.floor(firstRow / 2), 0])
    @editor.moveCursorUp(rowCount)

  backwardParagraph: (event) ->
    for cursor in @editor.getCursors()
      currentRow = @editor.getCursorBufferPosition().row

      break if currentRow <= 0

      cursorTools = new CursorTools(cursor)
      blankRow = cursorTools.locateBackward(/^\s+$|^\s*$/).start.row

      while currentRow == blankRow
        break if currentRow <= 0

        @editor.moveCursorUp()

        currentRow = @editor.getCursorBufferPosition().row
        blankRange = cursorTools.locateBackward(/^\s+$|^\s*$/)
        blankRow = if blankRange then blankRange.start.row else 0

      rowCount = currentRow - blankRow
      @editor.moveCursorUp(rowCount)

  forwardParagraph: (event) ->
    lineCount = @editor.buffer.getLineCount() - 1

    for cursor in @editor.getCursors()
      currentRow = @editor.getCursorBufferPosition().row
      break if currentRow >= lineCount

      cursorTools = new CursorTools(cursor)
      blankRow = cursorTools.locateForward(/^\s+$|^\s*$/).start.row

      while currentRow == blankRow
        @editor.moveCursorDown()

        currentRow = @editor.getCursorBufferPosition().row
        blankRow = cursorTools.locateForward(/^\s+$|^\s*$/).start.row

      rowCount = blankRow - currentRow
      @editor.moveCursorDown(rowCount)

  backwardKillWord: (event) ->
    @editor.transact =>
      for selection in @editor.getSelections()
        selection.modifySelection ->
          if selection.isEmpty()
            cursorTools = new CursorTools(selection.cursor)
            cursorTools.skipNonWordCharactersBackward()
            cursorTools.skipWordCharactersBackward()
          selection.deleteSelectedText()

  killWord: (event) ->
    @editor.transact =>
      for selection in @editor.getSelections()
        selection.modifySelection ->
          if selection.isEmpty()
            cursorTools = new CursorTools(selection.cursor)
            cursorTools.skipNonWordCharactersForward()
            cursorTools.skipWordCharactersForward()
          selection.deleteSelectedText()

  justOneSpace: (event) ->
    for cursor in @editor.cursors
      range = horizontalSpaceRange(cursor)
      @editor.setTextInBufferRange(range, ' ')

  deleteHorizontalSpace: (event) ->
    for cursor in @editor.cursors
      range = horizontalSpaceRange(cursor)
      @editor.setTextInBufferRange(range, '')

  recenterTopBottom: (event) ->
    minRow = Math.min((c.getBufferRow() for c in @editor.getCursors())...)
    maxRow = Math.max((c.getBufferRow() for c in @editor.getCursors())...)
    minOffset = @editorView.pixelPositionForBufferPosition([minRow, 0])
    maxOffset = @editorView.pixelPositionForBufferPosition([maxRow, 0])
    @editorView.scrollTop((minOffset.top + maxOffset.top - @editorView.scrollView.height())/2)

  cancel: (event) ->


  # cua-mode
  #   source: https://searchcode.com/codesearch/view/3662241/
  ############

  # Turn on rectangular marking mode by disabling transient mark mode
  # and manually handling highlighting from a post command hook.
  # Be careful if we are already marking a rectangle.
  cuaRectActivate: () ->


  # This is used to clean up after `cuaRectActivate'.
  cuaRectDeactivate: () ->
