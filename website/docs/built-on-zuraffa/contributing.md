# Contributing to the Showcase

Share what you built with Zuraffa v3. We keep the showcase simple and readable so new users can learn from real projects.

## Adding Your App to the Showcase

### Prerequisites

Before submitting your app, ensure it:
1. Uses Zuraffa as the primary architectural framework
2. Implements at least 3 major Zuraffa patterns (entity-based, single repository, orchestrator, or polymorphic)
3. Is publicly accessible (app store, web app, or public demo)
4. Has been in development for at least 30 days (to ensure stability)

### Submission Process

#### Option 1: Pull Request (Recommended)

1. **Fork and Clone**
   ```bash
   git clone https://github.com/arrrrny/zuraffa.git
   cd zuraffa
   ```

2. **Create Branch**
   ```bash
   git checkout -b showcase-your-app-name
   ```

3. **Update the Showcase**
   Edit `website/docs/built-on-zuraffa/showcase.md` and add your app in alphabetical order:
   
   ```markdown
   ### [Your App Name]
   **Downloads:** [Count]  
   **Link:** [URL]  
   **Description:** [Brief description of the app and how Zuraffa was used]

   **Zuraffa Features Used:**
   - [Feature 1]
   - [Feature 2]
   - [Feature 3]
   ```

4. **Commit and Push**
   ```bash
   git add website/docs/built-on-zuraffa/showcase.md
   git commit -m "Add [Your App Name] to showcase"
   git push origin showcase-your-app-name
   ```

5. **Create Pull Request**
   - Navigate to the Zuraffa repository on GitHub
   - Click "Compare & pull request"
   - Fill in the PR template with details about your app

#### Option 2: GitHub Issue

1. **Navigate to Issues**
   Visit [Zuraffa Issues](https://github.com/arrrrny/zuraffa/issues)

2. **Create New Issue**
   - Title: "Showcase Submission: [Your App Name]"
   - Template:
     ```
     ## App Information
   - Name: [Your App Name]
   - Link: [URL to app/store page]
   - Downloads/Installs: [Count if available]
   - Description: [Brief description of what the app does]
   
   ## Zuraffa Usage
   - How Zuraffa was used in the app
   - Which patterns were implemented (entity-based, single repository, orchestrator, polymorphic)
   - Any special features leveraged (caching, mocking, MCP server, etc.)
   
   ## Additional Information
   - Any interesting architecture decisions
   - Performance benefits noticed
   - Challenges overcome using Zuraffa
   ```

### Information Required

When submitting your app, please provide:

#### Basic Information
- **App Name**: The official name of your application
- **Link**: Direct link to the app (app store page, website, or demo)
- **Downloads/Installs**: Current download count or install statistics
- **Description**: 1-2 sentences about what your app does and its purpose

#### Zuraffa Implementation Details
- **Patterns Used**: Which Zuraffa patterns you implemented
- **Features Leveraged**: Specific Zuraffa features you utilized
- **Architecture Benefits**: How Zuraffa improved your development process
- **Scale**: Size of your team and app complexity

### Example Submission

Here's a complete example of how to format your submission:

```markdown
### TaskMaster Pro
**Downloads:** 50K+  
**Link:** [https://taskmasterpro.app](https://taskmasterpro.app)  
**Description:** A comprehensive project management application with real-time collaboration, AI-powered task suggestions, and offline-first capabilities. Built with Zuraffa's Clean Architecture for maintainable business logic and seamless offline experiences.

**Zuraffa Features Used:**
- Entity-based generation for Task, Project, and User entities
- Orchestrator pattern for complex workflow operations
- Caching with dual datasources for offline-first experience
- MCP server integration for AI agent development
- Mock data generation for rapid prototyping
- Dependency injection with get_it for clean separation
```

## Next Steps

- [Browse showcased apps](./showcase)
- [Architecture overview](../architecture/overview)
- [Features](../features/dependency-injection)
