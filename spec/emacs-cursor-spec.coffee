EditorState = require './editor-state'
EmacsCursor = require '../lib/emacs-cursor'
KillRing = require '../lib/kill-ring'

rangeCoordinates = (range) ->
  if range
    [range.start.row, range.start.column, range.end.row, range.end.column]
  else
    range

describe "EmacsCursor", ->
  beforeEach ->
    waitsForPromise =>
      atom.workspace.open().then (editor) =>
        @editor = editor
        @emacsCursor = EmacsCursor.for(editor.getLastCursor())

  describe "destroy", ->
    beforeEach ->
      EditorState.set(@editor, "[0].")
      @emacsCursor = EmacsCursor.for(@editor.getCursors()[0])
      @startingMarkerCount = @editor.getMarkerCount()

    it "cleans up markers set by the mark", ->
      @emacsCursor.mark().set().activate()
      expect(@editor.getMarkerCount()).toBeGreaterThan(@startingMarkerCount)

      @emacsCursor.destroy()
      expect(@editor.getMarkerCount()).toEqual(@startingMarkerCount)

    it "cleans up the yank marker", ->
      @emacsCursor.killRing().push('x')
      @emacsCursor.yank()
      expect(@editor.getMarkerCount()).toBeGreaterThan(@startingMarkerCount)

      @emacsCursor.destroy()
      expect(@editor.getMarkerCount()).toEqual(@startingMarkerCount)

  describe "mark", ->
    it "returns a mark for the cursor", ->
      EditorState.set(@editor, "a[0]b[1]c")
      [emacsCursor0, emacsCursor1] = (EmacsCursor.for(c) for c in @editor.getCursors())
      expect(emacsCursor0.mark().cursor).toBe(emacsCursor0.cursor)
      expect(emacsCursor1.mark().cursor).toBe(emacsCursor1.cursor)

    it "returns the same Mark each time for a cursor", ->
      a = @emacsCursor.mark()
      b = @emacsCursor.mark()
      expect(a).toBe(b)

  describe "killRing", ->
    it "returns a kill ring for the cursor", ->
      EditorState.set(@editor, "[0].[1]")
      [emacsCursor0, emacsCursor1] = (EmacsCursor.for(c) for c in @editor.getCursors())
      killRing0 = emacsCursor0.killRing()
      killRing1 = emacsCursor1.killRing()
      expect(killRing0.constructor).toBe(KillRing)
      expect(killRing1.constructor).toBe(KillRing)
      expect(killRing0).not.toBe(killRing1)

    it "returns the same KillRing each time for a cursor", ->
      a = @emacsCursor.killRing()
      b = @emacsCursor.killRing()
      expect(a).toBe(b)

  describe "locateBackward", ->
    it "returns the range of the previous match if found", ->
      EditorState.set(@editor, "xx xx [0] xx xx")
      range = @emacsCursor.locateBackward(/x+/)
      expect(rangeCoordinates(range)).toEqual([0, 3, 0, 5])
      expect(EditorState.get(@editor)).toEqual("xx xx [0] xx xx")

    it "returns null if no match is found", ->
      EditorState.set(@editor, "[0]")
      range = @emacsCursor.locateBackward(/x+/)
      expect(range).toBe(null)
      expect(EditorState.get(@editor)).toEqual("[0]")

  describe "locateForward", ->
    it "returns the range of the next match if found", ->
      EditorState.set(@editor, "xx xx [0] xx xx")
      range = @emacsCursor.locateForward(/x+/)
      expect(rangeCoordinates(range)).toEqual([0, 7, 0, 9])
      expect(EditorState.get(@editor)).toEqual("xx xx [0] xx xx")

    it "returns null if no match is found", ->
      EditorState.set(@editor, "[0]")
      range = @emacsCursor.locateForward(/x+/)
      expect(range).toBe(null)
      expect(EditorState.get(@editor)).toEqual("[0]")

  describe "locateWordCharacterBackward", ->
    it "returns the range of the previous word character if found", ->
      EditorState.set(@editor, " xx  [0]")
      range = @emacsCursor.locateWordCharacterBackward()
      expect(rangeCoordinates(range)).toEqual([0, 2, 0, 3])
      expect(EditorState.get(@editor)).toEqual(" xx  [0]")

    it "returns null if there are no word characters behind", ->
      EditorState.set(@editor, "  [0]")
      range = @emacsCursor.locateWordCharacterBackward()
      expect(range).toBe(null)
      expect(EditorState.get(@editor)).toEqual("  [0]")

  describe "locateWordCharacterForward", ->
    it "returns the range of the next word character if found", ->
      EditorState.set(@editor, "[0]  xx ")
      range = @emacsCursor.locateWordCharacterForward()
      expect(rangeCoordinates(range)).toEqual([0, 2, 0, 3])
      expect(EditorState.get(@editor)).toEqual("[0]  xx ")

    it "returns null if there are no word characters ahead", ->
      EditorState.set(@editor, "[0]  ")
      range = @emacsCursor.locateWordCharacterForward()
      expect(range).toBe(null)
      expect(EditorState.get(@editor)).toEqual("[0]  ")

  describe "locateNonWordCharacterBackward", ->
    it "returns the range of the previous nonword character if found", ->
      EditorState.set(@editor, "x  xx[0]")
      range = @emacsCursor.locateNonWordCharacterBackward()
      expect(rangeCoordinates(range)).toEqual([0, 2, 0, 3])
      expect(EditorState.get(@editor)).toEqual("x  xx[0]")

    it "returns null if there are no nonword characters behind", ->
      EditorState.set(@editor, "xx[0]")
      range = @emacsCursor.locateNonWordCharacterBackward()
      expect(range).toBe(null)
      expect(EditorState.get(@editor)).toEqual("xx[0]")

  describe "locateNonWordCharacterForward", ->
    it "returns the range of the next nonword character if found", ->
      EditorState.set(@editor, "[0]xx  x")
      range = @emacsCursor.locateNonWordCharacterForward()
      expect(rangeCoordinates(range)).toEqual([0, 2, 0, 3])
      expect(EditorState.get(@editor)).toEqual("[0]xx  x")

    it "returns null if there are no nonword characters ahead", ->
      EditorState.set(@editor, "[0]xx")
      range = @emacsCursor.locateNonWordCharacterForward()
      expect(range).toBe(null)
      expect(EditorState.get(@editor)).toEqual("[0]xx")

  describe "goToMatchStartBackward", ->
    it "moves to the start of the previous match and returns true if a match is found", ->
      EditorState.set(@editor, "xx xx [0] xx xx")
      result = @emacsCursor.goToMatchStartBackward(/x+/)
      expect(result).toBe(true)
      expect(EditorState.get(@editor)).toEqual("xx [0]xx  xx xx")

    it "does not move and returns false if no match is found", ->
      EditorState.set(@editor, "xx xx [0] xx xx")
      result = @emacsCursor.goToMatchStartBackward(/y+/)
      expect(result).toBe(false)
      expect(EditorState.get(@editor)).toEqual("xx xx [0] xx xx")

  describe "goToMatchStartForward", ->
    it "moves to the start of the next match and returns true if a match is found", ->
      EditorState.set(@editor, "xx xx [0] xx xx")
      result = @emacsCursor.goToMatchStartForward(/x+/)
      expect(result).toBe(true)
      expect(EditorState.get(@editor)).toEqual("xx xx  [0]xx xx")

    it "does not move and returns false if no match is found", ->
      EditorState.set(@editor, "xx xx [0] xx xx")
      result = @emacsCursor.goToMatchStartForward(/y+/)
      expect(result).toBe(false)
      expect(EditorState.get(@editor)).toEqual("xx xx [0] xx xx")

  describe "goToMatchEndBackward", ->
    it "moves to the end of the previous match and returns true if a match is found", ->
      EditorState.set(@editor, "xx xx [0] xx xx")
      result = @emacsCursor.goToMatchEndBackward(/x+/)
      expect(result).toBe(true)
      expect(EditorState.get(@editor)).toEqual("xx xx[0]  xx xx")

    it "does not move and returns false if no match is found", ->
      EditorState.set(@editor, "xx xx [0] xx xx")
      result = @emacsCursor.goToMatchEndBackward(/y+/)
      expect(result).toBe(false)
      expect(EditorState.get(@editor)).toEqual("xx xx [0] xx xx")

  describe "goToMatchEndForward", ->
    it "moves to the end of the next match and returns true if a match is found", ->
      EditorState.set(@editor, "xx xx [0] xx xx")
      result = @emacsCursor.goToMatchEndForward(/x+/)
      expect(result).toBe(true)
      expect(EditorState.get(@editor)).toEqual("xx xx  xx[0] xx")

    it "does not move and returns false if no match is found", ->
      EditorState.set(@editor, "xx xx [0] xx xx")
      result = @emacsCursor.goToMatchEndForward(/y+/)
      expect(result).toBe(false)
      expect(EditorState.get(@editor)).toEqual("xx xx [0] xx xx")

  describe "skipCharactersBackward", ->
    it "moves backward over the given characters", ->
      EditorState.set(@editor, "x..x..[0]")
      @emacsCursor.skipCharactersBackward('.')
      expect(EditorState.get(@editor)).toEqual("x..x[0]..")

    it "does not move if the previous character is not in the list", ->
      EditorState.set(@editor, "..x[0]")
      @emacsCursor.skipCharactersBackward('.')
      expect(EditorState.get(@editor)).toEqual("..x[0]")

    it "moves to the beginning of the buffer if all prior characters are in the list", ->
      EditorState.set(@editor, "..[0]")
      @emacsCursor.skipCharactersBackward('.')
      expect(EditorState.get(@editor)).toEqual("[0]..")

  describe "skipCharactersForward", ->
    it "moves forward over the given characters", ->
      EditorState.set(@editor, "[0]..x..x")
      @emacsCursor.skipCharactersForward('.')
      expect(EditorState.get(@editor)).toEqual("..[0]x..x")

    it "does not move if the next character is not in the list", ->
      EditorState.set(@editor, "[0]x..")
      @emacsCursor.skipCharactersForward('.')
      expect(EditorState.get(@editor)).toEqual("[0]x..")

    it "moves to the end of the buffer if all following characters are in the list", ->
      EditorState.set(@editor, "[0]..")
      @emacsCursor.skipCharactersForward('.')
      expect(EditorState.get(@editor)).toEqual("..[0]")

  describe "skipWordCharactersBackward", ->
    it "moves over any word characters backward", ->
      EditorState.set(@editor, "abc abc[0]abc abc")
      @emacsCursor.skipWordCharactersBackward()
      expect(EditorState.get(@editor)).toEqual("abc [0]abcabc abc")

    it "does not move if the previous character is not a word character", ->
      EditorState.set(@editor, "abc abc [0]")
      @emacsCursor.skipWordCharactersBackward()
      expect(EditorState.get(@editor)).toEqual("abc abc [0]")

    it "moves to the beginning of the buffer if all prior characters are word characters", ->
      EditorState.set(@editor, "abc[0]")
      @emacsCursor.skipWordCharactersBackward()
      expect(EditorState.get(@editor)).toEqual("[0]abc")

  describe "skipWordCharactersForward", ->
    it "moves over any word characters forward", ->
      EditorState.set(@editor, "abc abc[0]abc abc")
      @emacsCursor.skipWordCharactersForward()
      expect(EditorState.get(@editor)).toEqual("abc abcabc[0] abc")

    it "does not move if the next character is not a word character", ->
      EditorState.set(@editor, "[0] abc abc")
      @emacsCursor.skipWordCharactersForward()
      expect(EditorState.get(@editor)).toEqual("[0] abc abc")

    it "moves to the end of the buffer if all following characters are word characters", ->
      EditorState.set(@editor, "[0]abc")
      @emacsCursor.skipWordCharactersForward()
      expect(EditorState.get(@editor)).toEqual("abc[0]")

  describe "skipNonWordCharactersBackward", ->
    it "moves over any nonword characters backward", ->
      EditorState.set(@editor, "   x   [0]   x   ")
      @emacsCursor.skipNonWordCharactersBackward()
      expect(EditorState.get(@editor)).toEqual("   x[0]      x   ")

    it "does not move if the previous character is a word character", ->
      EditorState.set(@editor, "   x   x[0]")
      @emacsCursor.skipNonWordCharactersBackward()
      expect(EditorState.get(@editor)).toEqual("   x   x[0]")

    it "moves to the beginning of the buffer if all prior characters are nonword characters", ->
      EditorState.set(@editor, "   [0]")
      @emacsCursor.skipNonWordCharactersBackward()
      expect(EditorState.get(@editor)).toEqual("[0]   ")

  describe "skipNonWordCharactersForward", ->
    it "moves over any word characters forward", ->
      EditorState.set(@editor, "   x   [0]   x   ")
      @emacsCursor.skipNonWordCharactersForward()
      expect(EditorState.get(@editor)).toEqual("   x      [0]x   ")

    it "does not move if the next character is a word character", ->
      EditorState.set(@editor, "[0]x   x   ")
      @emacsCursor.skipNonWordCharactersForward()
      expect(EditorState.get(@editor)).toEqual("[0]x   x   ")

    it "moves to the end of the buffer if all following characters are nonword characters", ->
      EditorState.set(@editor, "[0]   ")
      @emacsCursor.skipNonWordCharactersForward()
      expect(EditorState.get(@editor)).toEqual("   [0]")

  describe "skipBackwardUntil", ->
    it "moves backward over the given characters", ->
      EditorState.set(@editor, "x..x..[0]")
      @emacsCursor.skipBackwardUntil(/[^\.]/)
      expect(EditorState.get(@editor)).toEqual("x..x[0]..")

    it "does not move if the previous character is not in the list", ->
      EditorState.set(@editor, "..x[0]")
      @emacsCursor.skipBackwardUntil(/[^\.]/)
      expect(EditorState.get(@editor)).toEqual("..x[0]")

    it "moves to the beginning of the buffer if all prior characters are in the list", ->
      EditorState.set(@editor, "..[0]")
      @emacsCursor.skipBackwardUntil(/[^\.]/)
      expect(EditorState.get(@editor)).toEqual("[0]..")

  describe "skipForwardUntil", ->
    it "moves forward over the given characters", ->
      EditorState.set(@editor, "[0]..x..x")
      @emacsCursor.skipForwardUntil(/[^\.]/)
      expect(EditorState.get(@editor)).toEqual("..[0]x..x")

    it "does not move if the next character is not in the list", ->
      EditorState.set(@editor, "[0]x..")
      @emacsCursor.skipForwardUntil(/[^\.]/)
      expect(EditorState.get(@editor)).toEqual("[0]x..")

    it "moves to the end of the buffer if all following characters are in the list", ->
      EditorState.set(@editor, "[0]..")
      @emacsCursor.skipForwardUntil(/[^\.]/)
      expect(EditorState.get(@editor)).toEqual("..[0]")

  describe "nextCharacter", ->
    it "returns the line separator if at the end of a line", ->
      EditorState.set(@editor, "ab[0]\ncd")
      expect(@emacsCursor.nextCharacter()).toEqual('\n')

    it "return null if at the end of the buffer", ->
      EditorState.set(@editor, "ab[0]")
      expect(@emacsCursor.nextCharacter()).toBe(null)

    it "returns the character to the right of the cursor otherwise", ->
      EditorState.set(@editor, "a[0]b\ncd")
      expect(@emacsCursor.nextCharacter()).toEqual('b')

  describe "previousCharacter", ->
    it "returns the line separator if at the end of a line", ->
      EditorState.set(@editor, "ab[0]\ncd")
      expect(@emacsCursor.nextCharacter()).toEqual('\n')

    it "return null if at the end of the buffer", ->
      EditorState.set(@editor, "ab[0]")
      expect(@emacsCursor.nextCharacter()).toBe(null)

    it "returns the character to the right of the cursor otherwise", ->
      EditorState.set(@editor, "a[0]b\ncd")
      expect(@emacsCursor.nextCharacter()).toEqual('b')

  describe "skipSexpForward", ->
    it "skips over the current symbol when inside one", ->
      EditorState.set(@editor, "a[0]bc de")
      @emacsCursor.skipSexpForward()
      expect(EditorState.get(@editor)).toEqual("abc[0] de")

    it "includes all symbol characters in the symbol", ->
      EditorState.set(@editor, "a[0]b_1c de")
      @emacsCursor.skipSexpForward()
      expect(EditorState.get(@editor)).toEqual("ab_1c[0] de")

    it "moves over any non-sexp chars before the symbol", ->
      EditorState.set(@editor, "[0] .-! ab")
      @emacsCursor.skipSexpForward()
      expect(EditorState.get(@editor)).toEqual(" .-! ab[0]")

    it "moves to the end of the buffer if there is nothing after the symbol", ->
      EditorState.set(@editor, "a[0]bc")
      @emacsCursor.skipSexpForward()
      expect(EditorState.get(@editor)).toEqual("abc[0]")

    it "skips over balanced parentheses if before an open parenthesis", ->
      EditorState.set(@editor, "a[0](b)c")
      @emacsCursor.skipSexpForward()
      expect(EditorState.get(@editor)).toEqual("a(b)[0]c")

    it "moves over any non-sexp chars before the opening parenthesis", ->
      EditorState.set(@editor, "[0] .-! (x)")
      @emacsCursor.skipSexpForward()
      expect(EditorState.get(@editor)).toEqual(" .-! (x)[0]")

    it "is not tricked by nested parentheses", ->
      EditorState.set(@editor, "a[0]((b c)(\n))d")
      @emacsCursor.skipSexpForward()
      expect(EditorState.get(@editor)).toEqual("a((b c)(\n))[0]d")

    it "is not tricked by backslash-escaped parentheses", ->
      EditorState.set(@editor, "a[0](b\\)c)d")
      @emacsCursor.skipSexpForward()
      expect(EditorState.get(@editor)).toEqual("a(b\\)c)[0]d")

    it "is not tricked by unmatched parentheses", ->
      EditorState.set(@editor, "a[0](b]c)d")
      @emacsCursor.skipSexpForward()
      expect(EditorState.get(@editor)).toEqual("a(b]c)[0]d")

    it "skips over balanced quotes (assuming it starts outside the quotes)", ->
      EditorState.set(@editor, 'a[0]"b c"d')
      @emacsCursor.skipSexpForward()
      expect(EditorState.get(@editor)).toEqual('a"b c"[0]d')

    it "moves over any non-sexp chars before the opening quote", ->
      EditorState.set(@editor, "[0] .-! 'x'")
      @emacsCursor.skipSexpForward()
      expect(EditorState.get(@editor)).toEqual(" .-! 'x'[0]")

    it "is not tricked by nested quotes of another type", ->
      EditorState.set(@editor, "a[0]'b\"c'd")
      @emacsCursor.skipSexpForward()
      expect(EditorState.get(@editor)).toEqual("a'b\"c'[0]d")

    it "does not move if it can't find a matching parenthesis", ->
      EditorState.set(@editor, "a[0](b")
      @emacsCursor.skipSexpForward()
      expect(EditorState.get(@editor)).toEqual("a[0](b")

    it "does not move if at the end of the buffer", ->
      EditorState.set(@editor, "a[0]")
      @emacsCursor.skipSexpForward()
      expect(EditorState.get(@editor)).toEqual("a[0]")

    it "does not move if before a closing parenthesis", ->
      EditorState.set(@editor, "(a [0]) b")
      @emacsCursor.skipSexpForward()
      expect(EditorState.get(@editor)).toEqual("(a [0]) b")

  describe "skipSexpBackward", ->
    it "skips over the current symbol when inside one", ->
      EditorState.set(@editor, "ab cd[0]e")
      @emacsCursor.skipSexpBackward()
      expect(EditorState.get(@editor)).toEqual("ab [0]cde")

    it "includes all symbol characters in the symbol", ->
      EditorState.set(@editor, "ab c_1d[0]e")
      @emacsCursor.skipSexpBackward()
      expect(EditorState.get(@editor)).toEqual("ab [0]c_1de")

    it "moves over any non-sexp chars after the symbol", ->
      EditorState.set(@editor, "ab .-! [0]")
      @emacsCursor.skipSexpBackward()
      expect(EditorState.get(@editor)).toEqual("[0]ab .-! ")

    it "moves to the beginning of the buffer if there is nothing before the symbol", ->
      EditorState.set(@editor, "ab[0]c")
      @emacsCursor.skipSexpBackward()
      expect(EditorState.get(@editor)).toEqual("[0]abc")

    it "skips over balanced parentheses if before an open parenthesis", ->
      EditorState.set(@editor, "a(b)[0]c")
      @emacsCursor.skipSexpBackward()
      expect(EditorState.get(@editor)).toEqual("a[0](b)c")

    it "moves over any non-sexp chars after the closing parenthesis", ->
      EditorState.set(@editor, "(x) .-! [0]")
      @emacsCursor.skipSexpBackward()
      expect(EditorState.get(@editor)).toEqual("[0](x) .-! ")

    it "is not tricked by nested parentheses", ->
      EditorState.set(@editor, "a((b c)(\n))[0]d")
      @emacsCursor.skipSexpBackward()
      expect(EditorState.get(@editor)).toEqual("a[0]((b c)(\n))d")

    it "is not tricked by backslash-escaped parentheses", ->
      EditorState.set(@editor, "a(b\\)c)[0]d")
      @emacsCursor.skipSexpBackward()
      expect(EditorState.get(@editor)).toEqual("a[0](b\\)c)d")

    it "is not tricked by unmatched parentheses", ->
      EditorState.set(@editor, "a(b[c)[0]d")
      @emacsCursor.skipSexpBackward()
      expect(EditorState.get(@editor)).toEqual("a[0](b[c)d")

    it "skips over balanced quotes (assuming it starts outside the quotes)", ->
      EditorState.set(@editor, 'a"b c"[0]d')
      @emacsCursor.skipSexpBackward()
      expect(EditorState.get(@editor)).toEqual('a[0]"b c"d')

    it "moves over any non-sexp chars after the closing quote", ->
      EditorState.set(@editor, "'x' .-! [0]")
      @emacsCursor.skipSexpBackward()
      expect(EditorState.get(@editor)).toEqual("[0]'x' .-! ")

    it "is not tricked by nested quotes of another type", ->
      EditorState.set(@editor, "a'b\"c'[0]d")
      @emacsCursor.skipSexpBackward()
      expect(EditorState.get(@editor)).toEqual("a[0]'b\"c'd")

    it "does not move if it can't find a matching parenthesis", ->
      EditorState.set(@editor, "a)[0]b")
      @emacsCursor.skipSexpBackward()
      expect(EditorState.get(@editor)).toEqual("a)[0]b")

    it "does not move if at the beginning of the buffer", ->
      EditorState.set(@editor, "[0]a")
      @emacsCursor.skipSexpBackward()
      expect(EditorState.get(@editor)).toEqual("[0]a")

    it "does not move if after an opening parenthesis", ->
      EditorState.set(@editor, "a ([0] b)")
      @emacsCursor.skipSexpBackward()
      expect(EditorState.get(@editor)).toEqual("a ([0] b)")

  describe "markSexp", ->
    it "selects the next sexp if the selection is not active", ->
      EditorState.set(@editor, "a[0] (b c) d")
      @emacsCursor.markSexp()
      expect(EditorState.get(@editor)).toEqual("a[0] (b c)(0) d")

    it "extends the selection over the next sexp if the selection is active", ->
      EditorState.set(@editor, "a[0] (b c)(0) (d e) f")
      @emacsCursor.markSexp()
      expect(EditorState.get(@editor)).toEqual("a[0] (b c) (d e)(0) f")

    it "extends to the end of the buffer if there is no following sexp", ->
      EditorState.set(@editor, "a[0] (b c)(0) ")
      @emacsCursor.markSexp()
      expect(EditorState.get(@editor)).toEqual("a[0] (b c) (0)")

    it "does nothing if the selection is extended to the end of the buffer", ->
      EditorState.set(@editor, "a[0] (b c)(0)")
      @emacsCursor.markSexp()
      expect(EditorState.get(@editor)).toEqual("a[0] (b c)(0)")

  describe "extractWord", ->
    it "removes and returns the word the cursor is in", ->
      EditorState.set(@editor, "aa bb[0]cc dd")
      word = @emacsCursor.extractWord()
      expect(word).toEqual("bbcc")
      expect(EditorState.get(@editor)).toEqual("aa [0] dd")

    it "removes and returns the word the cursor is at the start of", ->
      EditorState.set(@editor, "aa [0]bb cc")
      word = @emacsCursor.extractWord()
      expect(word).toEqual("bb")
      expect(EditorState.get(@editor)).toEqual("aa [0] cc")

    it "removes and returns the word the cursor is at the end of", ->
      EditorState.set(@editor, "aa bb[0] cc")
      word = @emacsCursor.extractWord()
      expect(word).toEqual("bb")
      expect(EditorState.get(@editor)).toEqual("aa [0] cc")

    it "returns an empty string and removes nothing if the cursor is not in a word", ->
      EditorState.set(@editor, "aa [0] bb")
      word = @emacsCursor.extractWord()
      expect(word).toEqual("")
      expect(EditorState.get(@editor)).toEqual("aa [0] bb")

    it "returns an empty string and removes nothing if not in a word at the start of the buffer", ->
      EditorState.set(@editor, "[0] aa")
      word = @emacsCursor.extractWord()
      expect(word).toEqual("")
      expect(EditorState.get(@editor)).toEqual("[0] aa")

    it "returns an empty string and removes nothing if not in a word at the end of the buffer", ->
      EditorState.set(@editor, "aa [0]")
      word = @emacsCursor.extractWord()
      expect(word).toEqual("")
      expect(EditorState.get(@editor)).toEqual("aa [0]")

    it "returns and removes the only word in a buffer if inside it", ->
      EditorState.set(@editor, "a[0]b")
      word = @emacsCursor.extractWord()
      expect(word).toEqual("ab")
      expect(EditorState.get(@editor)).toEqual("[0]")
