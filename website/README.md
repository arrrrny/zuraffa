# Zuraffa Documentation Website

This directory contains the Docusaurus-based documentation website for Zuraffa.

## Development

```bash
cd website
npm install
npm start
```

This starts a local development server at `http://localhost:3000`.

## Building

```bash
cd website
npm run build
```

This generates static content into the `build` directory.

## Deployment

The website is automatically deployed to GitHub Pages when changes are pushed to the `master` branch.

### Manual Deployment

```bash
cd website
GIT_USER=<Your GitHub username> npm run deploy
```

## Structure

```
website/
├── docs/                    # Documentation markdown files
│   ├── intro.md            # Landing page
│   ├── getting-started/    # Installation & setup
│   ├── cli/                # CLI documentation
│   ├── core-concepts/      # Architecture concepts
│   ├── features/           # Feature guides
│   └── examples/           # Code examples
├── src/                    # Custom React components
├── static/                 # Static assets
└── docusaurus.config.ts    # Site configuration
```

## Adding Documentation

1. Create a new `.md` file in the appropriate `docs/` subdirectory
2. Add frontmatter at the top:
   ```md
   ---
   sidebar_position: 1
   title: Your Title
   ---
   ```
3. The sidebar will automatically update

## Customization

- **Theme**: Edit `src/css/custom.css`
- **Navbar**: Edit `docusaurus.config.ts` → `themeConfig.navbar`
- **Footer**: Edit `docusaurus.config.ts` → `themeConfig.footer`
- **Sidebar**: Edit `sidebars.ts`
