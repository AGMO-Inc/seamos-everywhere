# C++ Usage Patterns

> **Status: Placeholder** — C++ code generation patterns are pending. The FeatureDesigner C++ generator currently fails when all plugins are injected.

## Known Status

- Plugin definitions (.fgd, Manifest.xml) are identical to Java
- C++ code generation templates (.cppjet) are not yet available
- The reference project at `reference_cpp/` has no `.gen` directory

## Language Detection

To determine if a project uses C++:
- Check for `.fgd` filename containing `_cpp`
- Check for `.gen` project with `.cppjet` templates
- Check `FDProject.props` for language setting
