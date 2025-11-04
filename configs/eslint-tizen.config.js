// ESLint configuration for Pyrrha Tizen Watch App
// Optimized for Tizen 5.5 and Galaxy Watch 3 development

export default [
  {
    files: ['**/*.js'],
    languageOptions: {
      ecmaVersion: 2020,
      sourceType: 'script', // Tizen uses script mode, not module
      globals: {
        // Tizen globals
        tizen: 'readonly',
        tau: 'readonly',
        window: 'readonly',
        document: 'readonly',
        console: 'readonly',

        // Samsung Accessory Protocol globals
        webapis: 'readonly',
        SAAgent: 'readonly',
        SASocket: 'readonly',
        SAMessage: 'readonly',

        // Watch app specific globals
        navigator: 'readonly',
        XMLHttpRequest: 'readonly',
        JSON: 'readonly',
        Date: 'readonly',
        Math: 'readonly',
        parseInt: 'readonly',
        parseFloat: 'readonly',
        setTimeout: 'readonly',
        setInterval: 'readonly',
        clearTimeout: 'readonly',
        clearInterval: 'readonly',

        // TAU Framework globals
        Page: 'readonly',
        Widget: 'readonly',

        // Custom app globals
        ProviderAppName: 'writable',
        CHANNELID: 'writable',
        TMP_RED: 'writable',
        HUM_RED: 'writable',
        CO_RED: 'writable',
        NO2_RED: 'writable',
        useToast: 'writable',
        notifyTmpHum: 'writable',

        // Additional app globals detected in watch app
        module: 'writable',
        createHTML: 'readonly',
      },
    },
    rules: {
      // Error prevention - warn only for existing code
      'no-undef': 'warn',
      'no-unused-vars': ['warn', { args: 'none' }],
      'no-redeclare': 'off', // Allow for Tizen compatibility
      'no-unreachable': 'warn',
      'no-constant-condition': 'warn',

      // Best practices for Tizen
      'no-eval': 'error',
      'no-implied-eval': 'error',
      'no-new-func': 'error',
      'no-with': 'error',
      strict: 'off', // Allow flexible strict mode for Tizen

      // Samsung Accessory Protocol best practices
      'no-empty-function': ['warn', { allow: ['arrowFunctions'] }],
      'consistent-return': 'warn',
      'default-case': 'warn',

      // Code style for Tizen development - warnings only
      indent: ['warn', 4], // Match existing Tizen code
      quotes: ['warn', 'double', { avoidEscape: true }],
      semi: ['warn', 'always'],
      'comma-dangle': ['warn', 'never'],
      'no-trailing-spaces': 'warn',
      'eol-last': 'warn',

      // Tizen-specific rules
      'no-alert': 'off', // Tizen uses native alerts
      'no-console': 'off', // Console logging is useful for debugging
      camelcase: ['warn', { properties: 'never' }],

      // Performance considerations for watch
      'no-loop-func': 'warn',
      'no-inner-declarations': 'warn',
      'prefer-const': 'warn',

      // Accessibility for watch interface
      'jsx-a11y/no-static-element-interactions': 'off',
      'jsx-a11y/click-events-have-key-events': 'off',
    },
  },
  {
    files: ['**/test/**/*.js', '**/*.test.js'],
    languageOptions: {
      globals: {
        describe: 'readonly',
        it: 'readonly',
        before: 'readonly',
        after: 'readonly',
        beforeEach: 'readonly',
        afterEach: 'readonly',
        expect: 'readonly',
        assert: 'readonly',
      },
    },
    rules: {
      'no-unused-expressions': 'off',
    },
  },
];
