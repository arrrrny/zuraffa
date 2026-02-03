# Contributing to the Showcase

Learn how to contribute your app to the Built on Zuraffa showcase and help grow our community of Clean Architecture practitioners.

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

## App Categories

We categorize showcased apps to help visitors find relevant examples:

### Productivity & Business
- Project management tools
- CRM systems
- Task managers
- Business automation

### Social & Communication
- Messaging apps
- Social networks
- Collaboration tools
- Community platforms

### E-commerce & Finance
- Shopping applications
- Payment systems
- Banking apps
- Marketplace platforms

### Media & Entertainment
- Streaming services
- Gaming applications
- Content platforms
- Creative tools

### Health & Fitness
- Workout trackers
- Health monitoring
- Medical applications
- Wellness platforms

### Education & Learning
- Course platforms
- Learning management
- Educational tools
- Training applications

## Review Criteria

Submissions are evaluated based on:

### Technical Merit
- Proper implementation of Zuraffa patterns
- Architectural soundness
- Code quality and organization
- Use of multiple Zuraffa features

### Public Availability
- App is publicly accessible
- Stable and maintained
- Clear purpose and functionality
- Professional presentation

### Community Value
- Demonstrates Zuraffa capabilities
- Provides learning value to others
- Represents diverse use cases
- Encourages Clean Architecture adoption

## Maintaining Your Listing

### Updates
- Update your listing if download counts change significantly
- Notify us if your app link becomes invalid
- Share major updates or new features

### Removal
Apps may be removed if:
- They become unavailable or inactive
- They no longer use Zuraffa significantly
- They violate community guidelines
- They receive multiple complaints

## Best Practices for Showcase Apps

### Architecture Excellence
- Follow Clean Architecture principles
- Use appropriate Zuraffa patterns for your use case
- Implement proper error handling with Result types
- Leverage dependency injection effectively

### Documentation
- Document your architecture decisions
- Share lessons learned with Zuraffa
- Provide insights for other developers
- Contribute to the community knowledge base

### Performance
- Optimize for performance with caching strategies
- Implement proper state management
- Use background operations appropriately
- Consider offline-first approaches where relevant

## Getting Help

### Questions
- Join our [Discord community](https://discord.gg/zuraffa) for discussions
- Open a [GitHub issue](https://github.com/arrrrny/zuraffa/issues) for technical questions
- Check the documentation for common patterns and solutions

### Support
- For technical issues with Zuraffa, use GitHub Issues
- For showcase-specific questions, contact the maintainers
- For partnership opportunities, reach out via the website

---

## Next Steps

- [Browse all showcased apps](./showcase) to see what others have built
- [Learn about architecture patterns](../architecture/overview) to enhance your app
- [Explore advanced features](../features/dependency-injection) to improve your implementation
- [Join our community](https://github.com/arrrrny/zuraffa) to connect with other developers

Thank you for contributing to the Zuraffa ecosystem! 🦒
