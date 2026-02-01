import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

const config: Config = {
  title: 'Zuraffa',
  tagline: 'Clean Architecture for Flutter — Type-safe, Result-based, Minimal Boilerplate',
  favicon: 'img/favicon.ico',

  // Future flags, see https://docusaurus.io/docs/api/docusaurus-config#future
  future: {
    v4: true, // Improve compatibility with the upcoming Docusaurus v4
  },

  // Set the production url of your site here
  url: 'https://zuraffa.com',
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: '/',

  // GitHub pages deployment config.
  // If you aren't using GitHub pages, you don't need these.
  organizationName: 'arrrrny', // Usually your GitHub org/user name.
  projectName: 'zuraffa', // Usually your repo name.

  onBrokenLinks: 'warn',

  // Even if you don't use internationalization, you can use this field to set
  // useful metadata like html lang. For example, if your site is Chinese, you
  // may want to replace "en" with "zh-Hans".
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          editUrl: 'https://github.com/arrrrny/zuraffa/tree/master/website/',
        },
        blog: false, // Disable blog for now
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    // Replace with your project's social card
    image: 'img/docusaurus-social-card.jpg',
    colorMode: {
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'Zuraffa',
      logo: {
        alt: 'Zuraffa Logo',
        src: 'img/logo.svg',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'tutorialSidebar',
          position: 'left',
          label: 'Docs',
        },
        {
          href: 'https://pub.dev/packages/zuraffa',
          label: 'pub.dev',
          position: 'right',
        },
        {
          href: 'https://github.com/arrrrny/zuraffa',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Docs',
          items: [
            {
              label: 'Getting Started',
              to: '/docs/intro',
            },
            {
              label: 'Dependency Injection',
              to: '/docs/features/dependency-injection',
            },
            {
              label: 'VPC Regeneration',
              to: '/docs/features/vpc-regeneration',
            },
          ],
        },
        {
          title: 'Community',
          items: [
            {
              label: 'GitHub',
              href: 'https://github.com/arrrrny/zuraffa',
            },
            {
              label: 'pub.dev',
              href: 'https://pub.dev/packages/zuraffa',
            },
          ],
        },
        {
          title: 'More',
          items: [
            {
              label: 'CLI Guide',
              href: 'https://github.com/arrrrny/zuraffa/blob/master/CLI_GUIDE.md',
            },
            {
              label: 'Example',
              href: 'https://github.com/arrrrny/zuraffa/tree/master/example',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} Zuraffa. Built with Docusaurus.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
