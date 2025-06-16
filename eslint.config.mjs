import globals from "globals";
import prettierPlugin from "eslint-plugin-prettier";

/** @type {import('eslint').Linter.FlatConfig[]} */
export default [
  {
    files: ["**/*.js"],
    languageOptions: {
      sourceType: "commonjs",
      globals: {
        ...globals.node,
      },
    },
    plugins: {
      prettier: prettierPlugin,
    },
    rules: {
      // Basic rules
      "no-dupe-args": "error", // Error on duplicate function arguments reference: // https://eslint.org/docs/latest/rules/no-dupe-args
      "no-dupe-keys": "error", // Error on duplicate keys in object literals
      "no-duplicate-case": "error", // Error on duplicate cases in `switch` statements
      "no-empty": "warn", // Warn on empty code blocks (can be disabled inline if intended)
      "no-func-assign": "error", // Prevent reassigning function declarations
      "no-irregular-whitespace": "warn", // Warn on irregular whitespace outside of strings and comments
      "no-unsafe-negation": "error", // Error on unsafe negation in relational operations (e.g., `!a in b`)
      "valid-typeof": "error", // Enforce valid `typeof` comparisons (e.g., `typeof foo === "string"`)

      //* Avoid Bugs
      "no-undef": "error", // Prevent use of undefined variables

      // Custom project-specific rules
      camelcase: [
        "error",
        {
          properties: "always",
          ignoreImports: true,
          allow: [],
        },
      ],
      eqeqeq: "error", // Require strict equality `===` and `!==`
      "no-unused-vars": ["warn", { argsIgnorePattern: "req|res|next|__" }], // Error on unused variables, except for function arguments
      "no-console": "error", // Warn when using `console` (for debugging only, avoid in production)
      "no-useless-catch": "off", // Allow try/catch blocks even if the catch block is redundant
      "no-invalid-this": "error", // Disallow `this` keywords outside of class methods or contexts where `this` binding is expected, helping prevent misuse of `this`.
      "no-return-assign": "error", // Disallow assignments in `return` statements, which can lead to unexpected side effects.

      "no-useless-concat": "error", // Disallow unnecessary string concatenation (e.g., combining literals), enforcing cleaner string handling.
      "no-useless-return": "error", // Disallow redundant `return` statements with no value, helping to keep code clean and free of unnecessary lines.

      //* ES6
      "arrow-spacing": "error", // Enforce spacing before and after `=>` in arrow functions
      "no-confusing-arrow": "error", // Prevent ambiguous arrow functions with implicit returns
      "no-duplicate-imports": "error", // Prevent duplicate imports of the same module
      "no-var": "error", // Disallow `var`, enforce `let` and `const` for block-scoped variables
      "object-shorthand": "off", // Allow flexibility with object literal shorthand syntax
      "prefer-const": "warn", // Require `const` for variables that are not reassigned
      "prefer-template": "warn", // Prefer template literals over string concatenation

      // Prettier plugin rules
      "prettier/prettier": "error", // Enforce Prettier formatting as an ESLint rule
    },
  },
  {
    ignores: ["node_modules/*", "**/.*", "events/event-schema.js"],
  },
];
