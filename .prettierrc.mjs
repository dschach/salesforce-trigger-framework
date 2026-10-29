import x2odPrettierConfig from '@x2od/prettier-config' with { type: 'json' };

/**
 * @see https://prettier.io/docs/configuration
 * @type {import("prettier").Config}
 */
const config = {
	...x2odPrettierConfig,
	useTabs: true,
	overrides: [
		...x2odPrettierConfig.overrides,
		{
			files: 'package.json',
			options: {
				printWidth: 100
			}
		},
		// The shared config sets XML to 120; the site recommends 180 for
		// every file, and its rulesets are published in that form.
		{
			files: '*.xml',
			options: {
				printWidth: 120
			}
		},
		{
			files: 'code-analyzer.yml',
			options: {
				singleQuote: false
			}
		},
		{
			files: 'pmd*.xml',
			options: {
				printWidth: 80
			}
		}
	]
};

export default config;
