# Projekt review – TrimrPix

## Findings (prioriteret)

### [Høj] Watch Folder kan re-optimere output og skabe loop
- Fil: `TrimrPix/Services/WatchFolderService.swift:153`
- Fil: `TrimrPix/Services/WatchFolderService.swift:165`
- Fil: `TrimrPix/Services/WatchFolderService.swift:174`
- Fil: `TrimrPix/Services/WatchFolderService.swift:231`
- Problem: `processNewFiles()` scanner hele mappen hver gang og optimerer alle billedfiler igen. Når auto-save skriver f.eks. `*-optimized.*`, trigger det nye events og bliver optimeret igen. Det kan føre til fil-eksplosion og høj CPU/disk.
- Anbefaling: Filtrer outputs (fx `*-optimized*`), track allerede-behandlede filer (URL + modifikationstid), eller håndter kun nye events i stedet for fuld scan.

### [Høj] Security-scoped adgang åbnes uden at blive lukket
- Fil: `TrimrPix/ViewModels/ImageOptimizationViewModel.swift:94`
- Fil: `TrimrPix/ViewModels/ImageOptimizationViewModel.swift:96`
- Problem: `startAccessingSecurityScopedResource()` kaldes per drop, men der kaldes aldrig `stopAccessingSecurityScopedResource()`. Det kan lække adgang og ramme systemets grænse for samtidige security-scoped handles.
- Anbefaling: Brug security-scoped bookmarks (persist) eller start/stop adgang omkring faktiske læse-/skriveoperationer. Luk adgang når et billede fjernes eller efter optimering.

### [Medium] Watch Folder læser Settings fra baggrundstråd
- Fil: `TrimrPix/Services/WatchFolderService.swift:162`
- Fil: `TrimrPix/Services/WatchFolderService.swift:202`
- Problem: `Task.detached` læser `settings.watchFolderDelay` uden trådsikring. `Settings` er `ObservableObject` uden actor-isolering, så det kan give data races.
- Anbefaling: Gør `Settings` til `@MainActor` og kopier værdier på main actor før baggrundsarbejde, eller gør `Settings` til en actor med async access.

### [Medium] Optimering udføres på MainActor og kan fryse UI
- Fil: `TrimrPix/ViewModels/ImageOptimizationViewModel.swift:161`
- Fil: `TrimrPix/ViewModels/ImageOptimizationViewModel.swift:195`
- Problem: ViewModel er `@MainActor`, og `compressionService.optimizeImage` laver synkron fil-IO/NSImage arbejde. Det risikerer UI-hak ved større batches, og TaskGroup giver ikke reel parallelitet på main thread.
- Anbefaling: Flyt komprimering til baggrundsopgaver (fx `Task.detached` eller en dedicated actor/queue), og opdater kun UI-state via `MainActor.run`.

### [Lav] Dependency injection ignoreres for WatchFolderService
- Fil: `TrimrPix/ViewModels/ImageOptimizationViewModel.swift:52`
- Fil: `TrimrPix/ViewModels/ImageOptimizationViewModel.swift:54`
- Problem: Hvis en mock `CompressionServiceProtocol` injiceres, bliver `WatchFolderService` stadig oprettet med en ny `CompressionService()`. Det gør tests inkonsistente.
- Anbefaling: Brug den injicerede `compressionService` til både `self.compressionService` og `WatchFolderService`.

### [Lav] Watch Folder mangler security-scoped bookmarks
- Fil: `TrimrPix/Views/SettingsView.swift:147`
- Fil: `TrimrPix/Views/SettingsView.swift:154`
- Problem: Kun sti gemmes fra `NSOpenPanel`. I sandbox vil adgang ikke overleve genstart uden bookmarks, og watch folder kan fejle efter relaunch.
- Anbefaling: Gem security-scoped bookmark data i `Settings` og genoptag adgang ved start (med `startAccessingSecurityScopedResource()`).

## Test gaps
- Mangler tests der bekræfter, at Watch Folder ikke reprocesser egne outputfiler.
- Mangler tests for security-scoped adgang (start/stop + bookmark flow) ved drag & drop og watch folder.
- Mangler performance-/responsiveness-tests for batch-optimering (UI må ikke fryse).

## Øvrige anbefalinger
- Overvej at markere `Settings` som `@MainActor` og kopiere værdier til lokale konstant(er) i services for tydeligere concurrency.
- Tilføj et enkelt flow-test (integration) for `optimizeAllImages()` med mockede services for at sikre korrekt state transitions (`isOptimizing`, `isOptimized`).

