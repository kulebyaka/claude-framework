---
allowed-tools: Bash, Read, Glob, Grep, TodoWrite
argument-hint: [--fix]
description: Build UI and .NET project, analyze errors, and suggest fixes (project)
model: sonnet
---

# Build Project and Analyze Issues

Build both the Angular frontend and .NET backend, identify build errors, and provide actionable solutions.

## Workflow

1. **Build Angular Frontend**
   - Change directory to `C:\Repos\github\hub-project\Frontend`
   - Run `npm run build` to build the Angular 19 application
   - Capture all build output including warnings and errors
   - Parse the output for:
     - TypeScript compilation errors
     - Angular template errors
     - ESLint errors (Angular ESLint 20.1.1)
     - Module resolution errors
     - Dependency warnings
     - Bundle size warnings
   - Note: Frontend uses Angular 19 with multi-tenant architecture (assets_altria/, assets_brownforman/, etc.)

2. **Build .NET Backend**
   - Change directory to `C:\Repos\github\hub-project\Backend`
   - Run `msbuild C:\Repos\github\hub-project\Backend\HubProjectApp.sln` to build the solution
   - Note: Uses .NET Framework v4.8.1
   - If MSBuild is not in PATH, try:
     - `"C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe" C:\Repos\github\hub-project\Backend\HubProjectApp.sln`
     - Or use Visual Studio 2019/2022 Developer Command Prompt path
   - Capture all build output including warnings and errors
   - Parse the output for:
     - Compilation errors (CS####)
     - Missing references
     - Namespace conflicts
     - Deprecated API usage warnings
     - Project reference issues
     - NuGet package restoration issues
     - .csproj file issues (common when new files are added but not referenced)

3. **Analyze Build Errors**
   - Create a structured summary of all errors found
   - Group errors by category:
     - **Critical Errors**: Build-breaking issues
     - **Warnings**: Non-blocking issues that should be addressed
     - **Informational**: Suggestions for improvement
   - For each error, identify:
     - File path and line number
     - Error code and message
     - Root cause analysis
     - Affected components

4. **Provide Solutions**
   - For each error/warning, provide:
     - Clear explanation of the issue
     - Step-by-step fix instructions
     - Code snippets showing the fix (if applicable)
     - File references with `file_path:line_number` format
     - Alternative approaches (if multiple solutions exist)
   - Prioritize fixes by:
     - Critical errors first (build blockers)
     - High-impact warnings second
     - Low-impact warnings last

5. **Generate Fix Recommendations**
   - Present all solutions in a structured format:
     ```
     ## Build Summary
     - Frontend: [PASSED/FAILED] - X errors, Y warnings
     - Backend: [PASSED/FAILED] - X errors, Y warnings

     ## Critical Issues (X)
     ### 1. [Error Type] in [File]
     **Error**: [Error message]
     **Location**: file_path:line_number
     **Cause**: [Root cause explanation]
     **Fix**: [Step-by-step solution]
     ```

6. **Ask User for Permission to Fix**
   - Present the complete analysis and suggested fixes
   - Ask: "Would you like me to apply these fixes automatically?"
   - Wait for user confirmation before proceeding

7. **Check for --fix Flag**
   - If $ARGUMENTS contains "--fix":
     - Skip step 6 (user confirmation)
     - Create a todo list with all fixes to be applied
     - Immediately begin implementing fixes systematically
     - Use TodoWrite to track progress
     - Apply fixes in order of priority:
       1. Critical errors (build blockers)
       2. High-impact warnings
       3. Low-impact warnings
     - After each fix, mark the todo as completed
     - Re-run the build to verify fixes
   - If --fix flag is not present:
     - Present analysis and wait for user approval
     - Ask if they want to proceed with fixes

8. **Verify Fixes (if applied)**
   - Re-run both builds after applying fixes
   - Compare before/after error counts
   - Report on:
     - Successfully resolved issues
     - Remaining issues (if any)
     - New issues introduced (if any)

## Build Error Pattern Recognition

### Common Frontend Errors (Angular 19)
- **TS2304**: Cannot find name - Missing import or type definition
- **TS2345**: Argument type mismatch - Incorrect parameter types
- **TS2307**: Cannot find module - Missing npm package or incorrect import path
- **NG####**: Angular-specific errors - Template or component issues
- **@angular-eslint/******: ESLint rule violations
- **Module not found**: Missing npm package or incorrect import path
- **Circular dependency**: Module import cycles
- **Translation key missing**: ngx-translate i18n issues

### Common Backend Errors (.NET Framework 4.8.1)
- **CS0246**: Type or namespace not found - Missing using directive or assembly reference
- **CS0103**: Name does not exist - Typo or missing declaration
- **CS1061**: Type does not contain definition - Missing method or property
- **CS0019**: Operator cannot be applied - Type mismatch in expression
- **CS0433**: Type exists in multiple assemblies - Assembly version conflict
- **CS0234**: Namespace does not exist - Missing NuGet package or incorrect reference
- **Missing .csproj reference**: File created but not added to project
- **Entity Framework errors**: .edmx model sync issues (Database First approach)
- **Autofac registration errors**: Dependency injection configuration issues

## Fix Implementation Guidelines

When applying fixes:
- **Read files before editing**: Always use Read tool before Edit/Write
- **Make minimal changes**: Only change what's necessary to fix the error
- **Preserve formatting**: Maintain existing code style and indentation
- **Add .csproj references**: When new C# files are created in Backend, ALWAYS add them to the corresponding .csproj file
  - This is a common source of build errors mentioned in CLAUDE.md
  - Example: If you create `PartnerManager.cs` in ABInBevBL, update `ABInBevBL.csproj`
- **Follow N-layer architecture**: API (ABInBevApp) → BL (ABInBevBL) → DL (ABInBevDL) → Model (ABInBevModel)
- **Test incrementally**: Re-build after each critical fix
- **Document changes**: Add XML documentation comments for new methods/classes
- **Follow dependency injection**: Use Autofac patterns for registering new services
- **Entity Framework**: For database changes, follow Database First approach with .edmx files
- **Multi-tenant aware**: Consider brand-specific assets and configurations for frontend changes

## Notes

- This command uses Bash for running build commands on Windows
- Build output can be lengthy - focus on errors/warnings first
- **Frontend build**: Angular 19 build typically takes 30-60 seconds
  - For faster local builds, developers use `npm run start_fast_local_multi`
  - Multi-tenant build includes brand-specific assets
- **Backend build**: .NET Framework 4.8.1 solution typically takes 1-2 minutes
  - MSBuild output is verbose - parse carefully for actual errors
  - Includes multiple projects: ABInBevApp, ABInBevBL, ABInBevDL, ABInBevModel, ABInBevDTO, JobScheduler, etc.
- MSBuild path issues: If `msbuild` command fails, try full Visual Studio path
- Some warnings are acceptable and can be ignored based on team standards
- Always verify that fixes don't introduce new issues
- **Key project technologies**:
  - Backend: ASP.NET Web API 2, Entity Framework 6, Autofac DI, log4net, JWT auth
  - Frontend: Angular 19, ngx-bootstrap, Angular Material, ngx-translate
- Reference CLAUDE.md for project-specific build conventions and architecture guidelines
