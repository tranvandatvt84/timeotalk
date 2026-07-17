# MVVP Structure

Use this structure for Flutter features in TimeoTalk. MVVP here means
Model, View, ViewModel, and Provider.

```text
lib/
  main.dart
  app/
    app.dart
    router.dart
    theme.dart
  core/
    constants/
    errors/
    network/
    storage/
    utils/
    widgets/
  features/
    feature_name/
      models/
        feature_model.dart
      providers/
        feature_provider.dart
      repositories/
        feature_repository.dart
      viewmodels/
        feature_view_model.dart
      views/
        feature_view.dart
        widgets/
          feature_widget.dart
```

## Layer Responsibilities

### Model

Models describe app data and should stay free of UI logic.

- Keep fields, serialization, parsing, and simple computed values here.
- Do not call APIs, read storage, navigate, or show widgets from models.
- Prefer immutable models where practical.

Example path:

```text
lib/features/chat/models/message_model.dart
```

### View

Views render UI and forward user actions to the ViewModel.

- Keep widgets focused on layout, display state, and input handling.
- Do not place business rules, API calls, or storage access in views.
- Split repeated UI into `views/widgets/`.

Example path:

```text
lib/features/chat/views/chat_view.dart
```

### ViewModel

ViewModels hold screen state and business logic for the View.

- Expose state that views can read.
- Validate user input before calling repositories.
- Coordinate loading, empty, success, and error states.
- Do not depend on Flutter widgets or `BuildContext`.

Example path:

```text
lib/features/chat/viewmodels/chat_view_model.dart
```

### Provider

Providers wire dependencies and expose ViewModels to the widget tree.

- Create and configure repositories, services, and ViewModels.
- Keep dependency setup in providers instead of views.
- Keep provider names clear and feature-scoped.

Example path:

```text
lib/features/chat/providers/chat_provider.dart
```

### Repository

Repositories are the data boundary for a feature.

- Fetch and persist data.
- Hide API, database, cache, or platform details from ViewModels.
- Return domain-friendly results or throw feature-specific errors.

Example path:

```text
lib/features/chat/repositories/chat_repository.dart
```

## Feature Template

When adding a new feature, start with this folder shape:

```text
lib/features/<feature_name>/
  models/
  providers/
  repositories/
  viewmodels/
  views/
    widgets/
```

Use singular file names for a single concept and descriptive names for screen
classes:

```text
profile_model.dart
profile_repository.dart
profile_view_model.dart
profile_provider.dart
profile_view.dart
```

## Data Flow

```text
View -> ViewModel -> Repository -> API / Storage
View <- ViewModel <- Repository <- API / Storage
```

- The View only talks to the ViewModel.
- The ViewModel talks to repositories and updates state.
- The Repository talks to external data sources.
- Providers connect these pieces together.

## Naming Rules

- Views end with `View`.
- ViewModels end with `ViewModel`.
- Providers end with `Provider`.
- Repositories end with `Repository`.
- Models end with `Model` only when it improves clarity.

## Testing Targets

- Test ViewModels for business logic and state transitions.
- Test repositories with mocked data sources.
- Test views with widget tests for important user flows.
- Keep model tests focused on parsing, serialization, and computed values.
