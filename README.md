# TrimrPix

## 📋 Beskrivelse
TrimrPix er en MacOS-app bygget med SwiftUI, der fokuserer på høj komprimeringskvalitet og et simpelt brugerinterface. Målet er at tilbyde en moderne og effektiv billedoptimeringsløsning med samme kernefunktionalitet som [ImageOptim](https://github.com/ImageOptim/ImageOptim), men med nyere teknologi og optimeret performance.

## ✨ Funktioner
- **Billedkomprimering** med fokus på høj kvalitet og reduceret filstørrelse.
- **Understøttelse af populære formater:** JPEG, PNG og GIF (WebP og AVIF planlagt til fremtidige versioner).
- **Drag & Drop Interface** til nem tilføjelse af billeder.
- **Batch-optimering** (optimer flere billeder ad gangen).
- **Visuel feedback:** Før/efter filstørrelse og procentuel reduktion.
- **Brugervalgt gemmested** for optimerede billeder.

## 🛠️ Teknologier
- **SwiftUI** – Moderne UI-udvikling til MacOS.
- **Core Image** – Billedbehandling og komprimering.
- **NSBitmapImageRep** – Effektiv billedkomprimering med kontrol over kvalitet.
- **Async/Await** – Moderne Swift concurrency for responsivt UI under billedbehandling.

## ⚙️ Arkitektur & Regler
- **Sandboxed App:** Appen er sandboxed for at sikre filsystembeskyttelse. Filadgang håndteres via **NSOpenPanel** og **NSSavePanel**.
- **Komprimeringslogik:** Vi benytter NSBitmapImageRep til billedoptimering med kontrolleret kvalitet.
- **Filskrivning:** Optimerede billeder gemmes som nye filer som standard (f.eks. `billede-optimized.png`) for at undgå datatab.
- **MVVM-arkitektur:** Appen følger Model-View-ViewModel mønstret for klar adskillelse af ansvar:
  - **Models:** Repræsenterer billeddata og metadata
  - **Views:** Håndterer brugergrænsefladen og interaktioner
  - **ViewModels:** Koordinerer dataflow og forretningslogik
- **Cursor Regler:**
  - Cursor må **ikke** opfinde nye funktioner, som ikke er specificeret i README.
  - Cursor skal sikre, at ændringer **ikke** påvirker eksisterende funktionalitet negativt.
  - Cursor skal være grundig og tjekke kode for konsistens og stabilitet.
  - Cursor skal kun implementere fremtidige features, hvis det specifikt bliver instrueret.

## 📁 Projektstruktur
```
TrimrPix/
├── TrimrPixApp.swift       # App entry point
├── ContentView.swift       # Hovedvisning med UI-komponenter
├── Models/
│   └── ImageItem.swift     # Datamodel for billeder
├── ViewModels/
│   └── ImageOptimizationViewModel.swift  # Håndterer billedoptimering
├── Services/
│   └── CompressionService.swift  # Billedkomprimeringslogik
├── TrimrPix.entitlements   # App sandboxing og tilladelser
└── README.md               # Projektbeskrivelse
```

## 🔧 Teknisk Implementering
- **Drag & Drop:** Implementeret med SwiftUI's `.onDrop` modifier og UTType.
- **Billedkomprimering:**
  - JPEG: Komprimering med 80% kvalitet for optimal balance mellem størrelse og kvalitet
  - PNG: Optimeret med standardindstillinger via NSBitmapImageRep
  - GIF: Grundlæggende håndtering (kopiering i MVP)
- **Concurrency:** Bruger Swift's moderne async/await mønster med @MainActor for UI-opdateringer
- **Filhåndtering:** NSSavePanel giver brugeren kontrol over, hvor optimerede billeder gemmes
- **Sandboxing:** Implementeret med korrekte entitlements for sikker filadgang

## ✅ MVP (Minimum Viable Product)
1. Enkel drag & drop af billeder.
2. Optimering af billeder med høj kvalitet.
3. Visning af filstørrelse før og efter optimering.
4. Understøttelse af JPEG, PNG og GIF.

## 🚀 Fremtidige Features *(Kun implementeres efter eksplicit instruktion)*
- **Brugerindstillinger:**
  - Mulighed for at vælge komprimeringsstyrke (lav/mellem/høj).
  - Valg mellem at overskrive originalfiler eller gemme som nye.
  - Indstillinger for outputmappe.
- **Udvidet formatunderstøttelse:**
  - Understøttelse af WebP og AVIF.
  - SVG-optimering med SVGO.
- **Automatisering:**
  - Watch-folder funktionalitet (automatisk optimering af nye filer i en mappe).
  - Batch-job system til større mængder filer.
- **Yderligere UI-forbedringer:**
  - Indstillingsmenu til konfiguration.
  - Før/efter billedeksempel.
- **Avanceret komprimering:**
  - Integration af MozJPEG og Zopfli for endnu bedre komprimeringsresultater.
  - Intelligent komprimering baseret på billedindhold.

## 📖 Installation
1. Klon repoet:
   ```bash
   git clone https://github.com/dinbruger/TrimrPix.git
   ```
2. Åbn projektet i Xcode.
3. Kør projektet på macOS.

## 🔍 Kendte begrænsninger
- GIF-optimering er begrænset til kopiering i den nuværende version.
- Appen kræver macOS 15.2 eller nyere.
- Billedoptimering sker synkront for hvert billede, hvilket kan påvirke performance ved store batches.

## 📢 Licens
MIT License – Fri til at bruge og tilpasse.

---