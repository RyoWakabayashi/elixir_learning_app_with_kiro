import * as monaco from "monaco-editor";

// Configure Monaco Editor for Elixir syntax highlighting
// Since Monaco doesn't have built-in Elixir support, we'll use a basic configuration
const ElixirLanguageConfig = {
  // Language configuration
  comments: {
    lineComment: '#',
    blockComment: ['"""', '"""']
  },
  brackets: [
    ['{', '}'],
    ['[', ']'],
    ['(', ')']
  ],
  autoClosingPairs: [
    { open: '{', close: '}' },
    { open: '[', close: ']' },
    { open: '(', close: ')' },
    { open: '"', close: '"' },
    { open: "'", close: "'" }
  ],
  surroundingPairs: [
    { open: '{', close: '}' },
    { open: '[', close: ']' },
    { open: '(', close: ')' },
    { open: '"', close: '"' },
    { open: "'", close: "'" }
  ]
};

// Elixir language tokens
const ElixirTokens = {
  tokenizer: {
    root: [
      // Keywords
      [/\b(def|defp|defmodule|defstruct|defimpl|defprotocol|defmacro|defmacrop|defguard|defguardp|defdelegate|defoverridable|defexception|if|unless|case|cond|with|for|try|receive|after|rescue|catch|else|end|do|when|and|or|not|in|fn|true|false|nil)\b/, 'keyword'],
      
      // Atoms
      [/:[a-zA-Z_][a-zA-Z0-9_]*[?!]?/, 'constant'],
      [/:"[^"]*"/, 'constant'],
      [/:'[^']*'/, 'constant'],
      
      // Strings
      [/"([^"\\]|\\.)*"/, 'string'],
      [/'([^'\\]|\\.)*'/, 'string'],
      [/"""/, 'string', '@string_heredoc'],
      [/'''/, 'string', '@string_heredoc_single'],
      
      // Numbers
      [/\b\d+(_\d+)*\b/, 'number'],
      [/\b\d+(_\d+)*\.\d+(_\d+)*\b/, 'number.float'],
      [/\b0x[0-9a-fA-F]+(_[0-9a-fA-F]+)*\b/, 'number.hex'],
      [/\b0o[0-7]+(_[0-7]+)*\b/, 'number.octal'],
      [/\b0b[01]+(_[01]+)*\b/, 'number.binary'],
      
      // Comments
      [/#.*$/, 'comment'],
      
      // Module names
      [/\b[A-Z][a-zA-Z0-9_]*\b/, 'type'],
      
      // Variables and function names
      [/\b[a-z_][a-zA-Z0-9_]*[?!]?\b/, 'identifier'],
      
      // Operators
      [/[+\-*\/=<>!&|^~%]/, 'operator'],
      [/[{}()\[\]]/, 'delimiter'],
      [/[,;.]/, 'delimiter'],
      
      // Pipe operator
      [/\|>/, 'operator.pipe'],
      
      // Sigils
      [/~[a-zA-Z]\[/, 'string.sigil', '@sigil_bracket'],
      [/~[a-zA-Z]\{/, 'string.sigil', '@sigil_brace'],
      [/~[a-zA-Z]\(/, 'string.sigil', '@sigil_paren'],
      [/~[a-zA-Z]\//, 'string.sigil', '@sigil_slash'],
      [/~[a-zA-Z]"/, 'string.sigil', '@sigil_quote'],
      [/~[a-zA-Z]'/, 'string.sigil', '@sigil_single'],
    ],
    
    string_heredoc: [
      [/"""/, 'string', '@pop'],
      [/./, 'string']
    ],
    
    string_heredoc_single: [
      [/'''/, 'string', '@pop'],
      [/./, 'string']
    ],
    
    sigil_bracket: [
      [/\]/, 'string.sigil', '@pop'],
      [/./, 'string.sigil']
    ],
    
    sigil_brace: [
      [/\}/, 'string.sigil', '@pop'],
      [/./, 'string.sigil']
    ],
    
    sigil_paren: [
      [/\)/, 'string.sigil', '@pop'],
      [/./, 'string.sigil']
    ],
    
    sigil_slash: [
      [/\//, 'string.sigil', '@pop'],
      [/./, 'string.sigil']
    ],
    
    sigil_quote: [
      [/"/, 'string.sigil', '@pop'],
      [/./, 'string.sigil']
    ],
    
    sigil_single: [
      [/'/, 'string.sigil', '@pop'],
      [/./, 'string.sigil']
    ]
  }
};

// Register Elixir language
monaco.languages.register({ id: 'elixir' });
monaco.languages.setLanguageConfiguration('elixir', ElixirLanguageConfig);
monaco.languages.setMonarchTokensProvider('elixir', ElixirTokens);

// Define Elixir theme
monaco.editor.defineTheme('elixir-theme', {
  base: 'vs',
  inherit: true,
  rules: [
    { token: 'keyword', foreground: '0000FF', fontStyle: 'bold' },
    { token: 'constant', foreground: '008080' },
    { token: 'string', foreground: '008000' },
    { token: 'string.sigil', foreground: '800080' },
    { token: 'comment', foreground: '808080', fontStyle: 'italic' },
    { token: 'number', foreground: 'FF0000' },
    { token: 'number.float', foreground: 'FF0000' },
    { token: 'number.hex', foreground: 'FF0000' },
    { token: 'number.octal', foreground: 'FF0000' },
    { token: 'number.binary', foreground: 'FF0000' },
    { token: 'type', foreground: '2B91AF' },
    { token: 'operator', foreground: '000000' },
    { token: 'operator.pipe', foreground: 'FF6600', fontStyle: 'bold' },
    { token: 'delimiter', foreground: '000000' }
  ],
  colors: {
    'editor.background': '#FFFFFF',
    'editor.foreground': '#000000',
    'editorLineNumber.foreground': '#999999',
    'editorCursor.foreground': '#000000',
    'editor.selectionBackground': '#ADD6FF',
    'editor.inactiveSelectionBackground': '#E5EBF1'
  }
});

// Monaco Editor LiveView Hook
const MonacoEditorHook = {
  mounted() {
    const container = this.el;
    const initialValue = container.dataset.initialValue || '';
    const language = container.dataset.language || 'elixir';
    const readOnly = container.dataset.readOnly === 'true';
    
    // Create Monaco Editor instance
    this.editor = monaco.editor.create(container, {
      value: initialValue,
      language: language,
      theme: 'elixir-theme',
      readOnly: readOnly,
      automaticLayout: true,
      minimap: { enabled: false },
      scrollBeyondLastLine: false,
      fontSize: 14,
      lineNumbers: 'on',
      roundedSelection: false,
      scrollbar: {
        vertical: 'auto',
        horizontal: 'auto'
      },
      wordWrap: 'on',
      tabSize: 2,
      insertSpaces: true,
      folding: true,
      lineDecorationsWidth: 10,
      lineNumbersMinChars: 3
    });

    // Handle content changes
    this.editor.onDidChangeModelContent(() => {
      const value = this.editor.getValue();
      this.pushEvent('update_code', { code: value });
    });

    // Handle validation
    this.setupValidation();
    
    // Store editor reference for external access
    container._monacoEditor = this.editor;
  },

  updated() {
    if (this.editor) {
      const newValue = this.el.dataset.initialValue || '';
      const currentValue = this.editor.getValue();
      
      // Only update if the value has actually changed to avoid cursor jumping
      if (newValue !== currentValue) {
        const position = this.editor.getPosition();
        this.editor.setValue(newValue);
        if (position) {
          this.editor.setPosition(position);
        }
      }
    }
  },

  destroyed() {
    if (this.editor) {
      this.editor.dispose();
    }
  },

  setupValidation() {
    // Basic Elixir syntax validation
    this.editor.onDidChangeModelContent(() => {
      const model = this.editor.getModel();
      const value = model.getValue();
      const markers = [];

      // Simple validation rules
      const lines = value.split('\n');
      lines.forEach((line, index) => {
        const lineNumber = index + 1;
        
        // Check for unmatched brackets
        const openBrackets = (line.match(/[\(\[\{]/g) || []).length;
        const closeBrackets = (line.match(/[\)\]\}]/g) || []).length;
        
        if (openBrackets !== closeBrackets) {
          markers.push({
            severity: monaco.MarkerSeverity.Warning,
            startLineNumber: lineNumber,
            startColumn: 1,
            endLineNumber: lineNumber,
            endColumn: line.length + 1,
            message: 'Possible unmatched brackets'
          });
        }
        
        // Check for basic syntax issues
        if (line.trim().endsWith('do') && !line.includes('def') && !line.includes('if') && !line.includes('case') && !line.includes('cond') && !line.includes('with') && !line.includes('for') && !line.includes('try') && !line.includes('receive')) {
          markers.push({
            severity: monaco.MarkerSeverity.Info,
            startLineNumber: lineNumber,
            startColumn: 1,
            endLineNumber: lineNumber,
            endColumn: line.length + 1,
            message: 'Consider adding corresponding "end" statement'
          });
        }
      });

      monaco.editor.setModelMarkers(model, 'elixir', markers);
    });
  }
};

export { MonacoEditorHook, monaco };