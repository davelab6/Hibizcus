//
//  WordsView.swift
//
//  Created by Muthu Nedumaran on 24/2/21.
//

import Combine
import SwiftUI
import AppKit

enum HBGridViewTab {
    case FontsTab, ClustersTab, WordsTab, NumbersTab
}

enum HBGridItemItemType {
    case Glyph, Cluster, Word, Number
}

struct HBGridItem : Hashable {
    var type: HBGridItemItemType?
    var text: String?
    var id          = UUID()                    // Unique ID for this item
    var glyphIds    = [kCGFontIndexInvalid,     // For Font1 and Font2
                       kCGFontIndexInvalid]
    var width       = [CGFloat(0),
                       CGFloat(0)]
    var height      = CGFloat(0)                // The rest of the data is for Font1 only
    var lsb         = CGFloat(0)
    var rsb         = CGFloat(0)
    var label       = ""                        // Stores the glyph name in the case of font comparison
    var uniLabel    = ""                        // Label that holds the unicode value
    var diffWidth   = false
    var diffGlyf    = false
    var diffLayout  = false
    var colorGlyphs = false
    func hasDiff() -> Bool {
        return diffWidth || diffGlyf || diffLayout
    }
}

class HBGridViewOptions: ObservableObject {
    @Published var matchOption: String          = WordSearchOptions.string.rawValue
    @Published var digitsOption: String         = NumberOfDigits.three.rawValue
    @Published var highlightPattern: Bool       = false         // To highlight the search pattern in matches, currently not used
    @Published var compareWordLayout: Bool      = false         // To initiate layout comparison in Words tab when 2 fonts are used
    @Published var showDiffsOnly: Bool          = false         // Only show the items that are different when two fonts are used
    @Published var currentTab: HBGridViewTab    = .FontsTab     // The currently active tab
    @Published var runningComparisons: Bool     = false         // Flag to indicate a comparison is running, so the UI can show activity
    @Published var showThousand: Bool           = false         // Insert a comma to show thousand in numbers with >= 4 digits
    @Published var showLakh: Bool               = false         // Insert a comma to show Lakh in a six digit number.
    @Published var colorGlyphs: Bool            = false         // Show each glyph in a different color - used in Cluster tab
}

struct HBGridView: View, DropDelegate {
    @Environment(\.openURL) var openURL
    @Binding var document: HibizcusDocument
    
    @StateObject var hbProject = HBProject()
    
    var projectFileUrl: URL?

    @StateObject var clusterViewModel           = HBGridSidebarClusterViewModel()
    @StateObject var gridViewOptions            = HBGridViewOptions()
    
    // Used across all tabs
    @State var hbGridItems                      = [HBGridItem]()
    @State var minCellWidth: CGFloat            = 100
    @State var maxCellWidth: CGFloat            = 100  // 150
    
    // Used in FontTab
    @State var glyphItems                       = [HBGridItem]()
    @State var glyphCellWidth:CGFloat           = 100
    
    // Used in Words tab
    @State var theText                          = ""
    
    @State var showGlyphView                    = false
    @State var tappedItem                       = HBGridItem()
    
    var body: some View {
        NavigationView() {
            HBGridSidebarView(gridViewOptions: gridViewOptions, clusterViewModel: clusterViewModel)
                .onChange(of: gridViewOptions.matchOption) { value in
                    print("Time to refresh search with \(gridViewOptions.matchOption) for script \(hbProject.hbFont1.selectedScript) in language \(hbProject.hbFont1.selectedLanguage)")
                    refreshGridItems()
                }
                .onChange(of: gridViewOptions.compareWordLayout) { value in
                    refreshGridItems()
                }
                .onChange(of: gridViewOptions.digitsOption) { value in
                    refreshGridItems()
                }
                .onChange(of: gridViewOptions.showThousand) { value in
                    if gridViewOptions.showLakh {
                        gridViewOptions.showThousand = true
                    }
                    updateNumberItems()
                }
                .onChange(of: gridViewOptions.showLakh) { value in
                    if value {
                        gridViewOptions.showThousand = true
                    }
                    updateNumberItems()
                }
                .onChange(of: gridViewOptions.colorGlyphs) { value in
                    if hbProject.hbFont2.fileUrl != nil {
                        // Do not allow color if we are comparing
                        gridViewOptions.colorGlyphs = false
                    }
                    refreshGridItems()
                }
                .onChange(of: gridViewOptions.currentTab) { newTab in
                    print("Tab switched to \(newTab)")
                    refreshGridItems()
                }
                .onChange(of: hbProject.hbFont1.selectedScript) { newScript in
                    print("Script has changed from \(clusterViewModel.currentScript) to \(newScript)")
                    clusterViewModel.currentScript = newScript
                    glyphItems.removeAll()
                    refreshGridItems()
                }
                .onChange(of: hbProject.hbFont1.selectedLanguage) { newLanguage in
                    print("Language has changed to \(newLanguage)")
                    glyphItems.removeAll()
                    refreshGridItems()
                }
                .onChange(of: hbProject.hbFont1.fileWatcher.fontFileChanged) { _ in
                    print("Font file changed - need to redraw the UI")
                    hbProject.refresh()
                }
                .onChange(of: hbProject.hbFont2.fileWatcher.fontFileChanged) { _ in
                    print("Font file changed - need to redraw the UI")
                    hbProject.refresh()
                }
            VStack {
                if gridViewOptions.currentTab == HBGridViewTab.WordsTab {
                    VStack {
                        TextField(Hibizcus.UIString.TestStringPlaceHolder, text: $theText)
                            .font(.title)
                            .onChange(of: theText) { _ in
                                UserDefaults.standard.set(theText, forKey: Hibizcus.Key.WVString)
                                refreshGridItems()
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 5)
                        if ( gridViewOptions.currentTab == HBGridViewTab.WordsTab ) {
                            Text(theText.hexString())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .font(.body)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 5)
                        }
                    }
                    .border(Color.primary.opacity(0.3), width: 1)
                }
                if hbProject.hbFont1.ctFont != nil && hbProject.hbFont1.fileUrl != nil {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: maxCellWidth))], spacing: 10) {
                            ForEach(hbGridItems, id: \.self) { hbGridItem in
                                if !gridViewOptions.showDiffsOnly || (gridViewOptions.showDiffsOnly && hbGridItem.hasDiff()) {
                                    HBGridCellViewRepresentable(wordItem: hbGridItem, scale: 1.0)//, viewOptions: gridViewOptions)
                                        .frame(width: maxCellWidth, height: 92, alignment: .center)
                                        .border(Color.primary.opacity(0.7), width: tappedItem==hbGridItem ? 1 : 0)
                                        .gesture(TapGesture(count: 2).onEnded {
                                            // UI Update should be done on main thread
                                            DispatchQueue.main.async {
                                                tappedItem = hbGridItem
                                            }
                                            print("double clicked on item \(hbGridItem)")
                                            doubleClicked(clickedItem: hbGridItem)
                                        })
                                        .simultaneousGesture(TapGesture().onEnded {
                                            DispatchQueue.main.async {
                                                tappedItem = hbGridItem
                                            }
                                            print("single clicked on item \(hbGridItem)")
                                        })
                                        .onDrag({
                                            let dragData = jsonFrom(font1:hbProject.hbFont1, font2:hbProject.hbFont2, text:hbGridItem.text!)
                                            UserDefaults.standard.setValue(dragData, forKey: "droppedjson")
                                            print("Dragging out \(dragData)")
                                            return NSItemProvider(item: dragData as NSString, typeIdentifier: kUTTypeText as String)
                                        })
                                        .sheet(isPresented: $showGlyphView, onDismiss: glyphViewDismissed) {
                                            HBGlyphView(tapped: tappedItem, items: hbGridItems)
                                            // TODO: The above can be replaced with the code below when it can be complied without any swift compile errors
                                            // See notes above init func in HBGLyphView
                                            //HBGlyphView(scale: tappedItem.type == .Word ? 4.0 : 6.0, currItem: hbGridItems.firstIndex(of: tappedItem) ?? 0, items: hbGridItems)
                                        }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .background(Color(NSColor.textBackgroundColor))
                    }
                    Divider()
                    HStack {
                        Text(tappedItem.text ?? "")
                            .font(.system(size: 12, design: .monospaced))
                            .padding(.top, 1)
                            .padding(.bottom, 5)
                            .padding(.leading, 20)
                        Spacer()
                        Text("\(hbGridItems.count) Items")
                            .font(.system(size: 12, design: .monospaced))
                            .padding(.top, 1)
                            .padding(.bottom, 5)
                            .padding(.trailing, 20)
                    }
                } else {
                    Spacer()
                    Text(Hibizcus.UIString.DragAndDropTwoFontFiles)
                        .font(.title)
                        .padding(.vertical, 50)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            }
            .toolbar {
                // Toggle sidebar
                ToolbarItem(placement: .navigation) {
                    Button(action: toggleLeftSidebar, label: {
                        Image(systemName: "sidebar.left")
                    })
                }
                // Copy buton
                ToolbarItem(placement: ToolbarItemPlacement.automatic) {
                    Button(action: {
                        if tappedItem.text != nil && tappedItem.text != "" {
                            copyTextToClipboard(textToCopy: tappedItem.text!)
                        }
                    }, label: {
                        Image(systemName: "doc.on.doc")
                    })
                    .help((tappedItem.text != nil && tappedItem.text != "") ? "Copy \(tappedItem.text!) to clipboard" : "")
                    .disabled(tappedItem.text == nil || tappedItem.text == "")
                }
                // String Viewer
                ToolbarItem(placement: ToolbarItemPlacement.automatic) {
                    Button(action: {
                        if let url = URL(string: "Hibizcus://stringview?\(urlParamsForToolWindow(text: tappedItem.text ?? ""))") {
                            hbProject.hbStringViewText = tappedItem.text ?? ""
                            openURL(url)
                        }
                    }, label: {
                        Image(systemName: "rectangle.and.text.magnifyingglass")
                    })
                    .help((tappedItem.text != nil && tappedItem.text != "") ? "Open \(tappedItem.text!) in StringViewer" : "Open StringViewer")
                }
                // TraceView
                ToolbarItem(placement: ToolbarItemPlacement.automatic) {
                    Button(action: {
                        if let url = URL(string: "Hibizcus://traceview") {
                            hbProject.hbTraceViewText = tappedItem.text ?? ""
                            openURL(url)
                        }
                    }, label: {
                        Image(systemName: "list.bullet.rectangle")
                    })
                    .help((tappedItem.text != nil && tappedItem.text != "") ? "Open \(tappedItem.text!) in TraceViewer" : "Open TraceViewer")
                }
            }
            .navigationTitle("Hiziscus Font Tools")
            .onChange(of: clusterViewModel.selectedBase) { _ in
                refreshGridItems()
            }
            .onChange(of: clusterViewModel.addNukta) { _ in
                refreshGridItems()
            }
            .onChange(of: clusterViewModel.selectedSubConsonant) { _ in
                refreshGridItems()
            }
            .onChange(of: clusterViewModel.selectedVowelSign) { _ in
                refreshGridItems()
            }
            .onChange(of: clusterViewModel.selectedOtherSign) { _ in
                refreshGridItems()
            }
            .onChange(of: clusterViewModel.justLoadedFromFile) { _ in
                clusterViewModel.justLoadedFromFile = false
                //refreshGridItems()
            }
        }
        .navigationTitle("Hibizcus")
        .onDrop(of: ["public.truetype-ttf-font", "public.file-url"], delegate: self)
        .onAppear {
            if document.projectData.fontFile1Bookmark != nil {
                hbProject.hbFont1.loadFontWith(fontBookmark: document.projectData.fontFile1Bookmark!, fontSize: 40)
            }
            if document.projectData.fontFile2Bookmark != nil {
                hbProject.hbFont2.loadFontWith(fontBookmark: document.projectData.fontFile2Bookmark!, fontSize: 40)
            }
            
            if projectFileUrl != nil {
                hbProject.projectName = projectFileUrl!.lastPathComponent
            }
            
            clusterViewModel.currentScript = hbProject.hbFont1.selectedScript
            glyphItems.removeAll()
            hbProject.refresh()
            refreshGridItems()
        }
        .environmentObject(hbProject)
    }
    
    func urlParamsForToolWindow(text: String) -> String {
        let etext = text.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        let pfUrl = projectFileUrl?.absoluteString ?? "none"
        let f1Url = hbProject.hbFont1.fileUrl?.absoluteString ?? "none"
        let f2Url = hbProject.hbFont1.fileUrl?.absoluteString ?? "none"
        return "text=\(etext)&projectfileurl=\(pfUrl)&font1Url=\(f1Url)&font2Url=\(f2Url)"
    }
    
    func performDrop(info: DropInfo) -> Bool {
        guard info.hasItemsConforming(to: ["public.file-url"]) else {
            return false
        }
        
        guard let itemProvider = info.itemProviders(for: [(kUTTypeFileURL as String)]).first else { return false }
        
        itemProvider.loadItem(forTypeIdentifier: (kUTTypeFileURL as String), options: nil) {item, error in
            guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            // There should be a better way to determine filetype
            let urlstring = url.absoluteString.lowercased()
            if urlstring.hasSuffix(".ttf") || urlstring.hasSuffix(".otf") || urlstring.hasSuffix(".ttc") {
                DispatchQueue.main.async {
                    if hbProject.hbFont1.fileUrl == nil {
                        setHBFont(fromUrl: url, asMainFont: true)
                    }
                    else {
                        setHBFont(fromUrl: url, asMainFont: false)
                    }
                }
            }
        }
        
        return true
    }
    
    // Set font file from a url, dragged and dropped or opened via (+) button
    func setHBFont(fromUrl: URL, asMainFont: Bool) {
        if asMainFont {
            hbProject.hbFont1.fontSize = 40
            hbProject.hbFont1.setFontFile(filePath: fromUrl.path)
            // Save the bookmark in document for future use
            document.projectData.fontFile1Bookmark = securityScopedBookmark(ofUrl: fromUrl)
        }
        else {
            hbProject.hbFont1.fontSize = 40
            hbProject.hbFont2.setFontFile(filePath: fromUrl.path)
            // Save the bookmark in document for future use
            document.projectData.fontFile2Bookmark = securityScopedBookmark(ofUrl: fromUrl)
        }
        clusterViewModel.currentScript = hbProject.hbFont1.selectedScript
        glyphItems.removeAll()
        hbGridItems.removeAll()
        hbProject.refresh()
        refreshGridItems()
    }
    
    func securityScopedBookmark(ofUrl: URL) -> Data {
        // Create a security scoped bookmark so we can open this again in the future
        let bookmarkData = try! ofUrl.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        return bookmarkData
    }
    
    func doubleClicked(clickedItem: HBGridItem) {
        showGlyphView = tappedItem == clickedItem
    }
    
    func refreshGridItems() {
        // Reset the tapped item
        tappedItem = HBGridItem()
        
        if gridViewOptions.currentTab == HBGridViewTab.FontsTab {
            refreshGlyphsInFonts()
        }
        else if gridViewOptions.currentTab == HBGridViewTab.ClustersTab {
            refreshClusters()
        }
        else if gridViewOptions.currentTab == HBGridViewTab.WordsTab {
            refreshWordsFromList()
        }
        else {
            refreshNumbers()
        }
    }
    
    func glyphViewDismissed() {
        showGlyphView = false
    }
    
    // MARK: ----- Refresh Glyphs in Font

    func refreshGlyphsInFonts() {
        print("Refreshing items in Font tab")
        hbGridItems.removeAll()
        if hbProject.hbFont1.fileUrl != nil {
            // If we already have the data backed up, use it instead of recreating
            if glyphItems.count > 0 && glyphItems.count == hbProject.hbFont1.glyphCount {
                hbGridItems = glyphItems
                maxCellWidth = glyphCellWidth
                return
            }
            
            glyphItems.removeAll()
            
            // Easier to get glyphname in a CGFont
            let cgFont = CTFontCopyGraphicsFont(hbProject.hbFont1.ctFont!, nil)
            
            let fontData1   = hbProject.hbFont1.getHBFontData()
            let fontData2   = hbProject.hbFont2.getHBFontData()
            let cgFont2     = hbProject.hbFont2.fileUrl != nil ? CTFontCopyGraphicsFont(hbProject.hbFont2.ctFont!, nil) : nil
            
            // Get the glyph information and set the width of the widest glyph as the maxCellWidth
            glyphCellWidth  = 100
            let scale       = (Hibizcus.FontScale / (2048/hbProject.hbFont1.metrics.upem)) * (192/40)
            // Let's run this in the background as it can take very long for large fonts
            DispatchQueue.global(qos: .background).async {
                for i in 0 ..< hbProject.hbFont1.glyphCount {
                    let gId         = CGGlyph(i)
                    let gName       = cgFont.name(for: gId)! as String
                    let fd1         = fontData1!.getGlyfData(forGlyphName: gName)
                    let adv         = fd1?.width ?? 0
                    let width       = CGFloat(Float(adv)/scale)
                    var wordItem    = HBGridItem(type:HBGridItemItemType.Glyph, text: "")
                    wordItem.glyphIds[0]    = gId
                    wordItem.width[0]       = width
                    wordItem.label          = gName
                    wordItem.uniLabel       = hbProject.hbFont1.unicodeLabelForGlyphId(glyph: gId)
                    //var hasDiff     = false // no difference
                    var widthDiff   = false
                    var glyfDiff    = false
                    if (fontData2 != nil) {
                        let fd2     = fontData2!.getGlyfData(forGlyphName: gName)
                        glyfDiff    = fd1?.glyf != fd2?.glyf
                        let gId2    = cgFont2?.getGlyphWithGlyphName(name: gName as CFString)
                        wordItem.glyphIds[1] = gId2 != nil ? CGGlyph(gId2!) : kCGFontIndexInvalid
                        let adv2    = fd2?.width ?? 0
                        wordItem.width[1] = CGFloat(Float(adv2)/scale)
                        widthDiff   = abs(width - wordItem.width[1]) > 0.01
                    }
                    //wordItem.hasDiff  = hasDiff
                    wordItem.diffGlyf   = glyfDiff
                    wordItem.diffWidth  = widthDiff
                    glyphCellWidth = max(width, glyphCellWidth)
                    DispatchQueue.main.async {
                        hbGridItems.append(wordItem)
                        glyphItems.append(wordItem)
                        maxCellWidth = glyphCellWidth
                        //print("Grid now has \(hbGridItems.count) glyphs")
                    }
                }
            }
        }
        
        return
    }
    
    // MARK: ----- Refresh Clusters

    func refreshClusters() {
        print("Refreshing items in Clusters tab")
        hbGridItems.removeAll()
        var maxWidth: CGFloat = 100 //maxCellWidth
        
        // This will be used to compare glyf data
        let fontData1   = hbProject.hbFont1.getHBFontData()
        let fontData2   = hbProject.hbFont2.getHBFontData()
        
        for base in clusterViewModel.baseStrings {
            var baseEx = base
            // do we need to add nukta
            if clusterViewModel.addNukta {
                baseEx += clusterViewModel.nukta
            }
            // do we add sub conso?
            if clusterViewModel.selectedSubConsonant != "None" {
                if clusterViewModel.selectedSubConsonant == "Reph" ||
                    clusterViewModel.selectedSubConsonant == "Repha" ||
                    clusterViewModel.selectedSubConsonant == "Repaya" ||
                    clusterViewModel.selectedSubConsonant == "Ra Initial" {
                    baseEx = clusterViewModel.subConsonantString + baseEx
                }
                else {
                    baseEx += clusterViewModel.subConsonantString
                }
            }
            // do we have a vowel selected?
            if clusterViewModel.selectedVowelSign.count > 0 {
                baseEx += clusterViewModel.selectedVowelSign
            }
            // Other signs?
            if clusterViewModel.selectedOtherSign.count > 0 {
                baseEx += clusterViewModel.selectedOtherSign
            }
            
            // Get the width
            let sld1 = hbProject.hbFont1.getStringLayoutData(forText: baseEx)
            maxWidth = max(sld1.width, maxWidth)

            var item = HBGridItem(type:HBGridItemItemType.Cluster, text: baseEx, colorGlyphs: gridViewOptions.colorGlyphs)
            item.width[0] = (sld1.width)
            
            // If there are two fonts, see if we have a diff
            if hbProject.hbFont2.fileUrl != nil {
                if baseEx == "ल्क्य" || baseEx == "क़" || baseEx == "கா" {
                    print("Debugging \(baseEx)")
                }
                let sld2 = hbProject.hbFont2.getStringLayoutData(forText: baseEx)
                item.width[1] = sld2.width
                item.diffWidth = abs(item.width[1] - item.width[0]) > 0.01
                item.diffLayout = !(sld1 == sld2)
                for hbGlyph in sld1.hbGlyphs {
                    let fd1 = fontData1!.getGlyfData(forGlyphName: hbGlyph.name)
                    let fd2 = fontData2!.getGlyfData(forGlyphName: hbGlyph.name)
                    if fd1 != nil && fd2 != nil {
                        if fd1!.glyf != fd2!.glyf {
                            item.diffGlyf = true
                            break
                        }
                    }
                }
            }
            hbGridItems.append(item)
        }
        
        minCellWidth = CGFloat(Double(maxWidth) * 1.1)
        maxCellWidth = CGFloat(Double(maxWidth) * 1.1)
    }
    
    
    // MARK: ----- Refresh Words from List
    
    func refreshWordsFromList() {
        print("Refreshing items in Words tab")
        print ("I need to load word data for \(hbProject.hbFont1.selectedScript)-\(hbProject.hbFont1.selectedLanguage)")
         
        // Handle script names w more than a word
        var script = hbProject.hbFont1.selectedScript.hasPrefix("Odia") ? "odia" : hbProject.hbFont1.selectedScript.lowercased()
        script = hbProject.hbFont1.selectedScript.hasPrefix("Meitei Mayek") ? "meeteimayek" : script
        
        // Get the language name, if it's specified as default
        var language = hbProject.hbFont1.selectedLanguage.lowercased()
        if language == "default" {
            language = defaultLanguage(forScript: script).lowercased()
        }
        
        let filename = script + "_" + language
        if let filepath = Bundle.main.path(forResource: filename, ofType: "txt") {
            // Get groups - for searches that involve letters instead of unicodes
            var groups = ""
            for letter in theText {
                if groups.count > 0 {
                    groups += "|"
                }
                groups += "(\(letter))"
            }
            
            do {
                let contents = try String(contentsOfFile: filepath)
                // Default pattern is to look for strings that contain theText
                // TODO: Contain this to a max of 4 chars before and after?
                var pattern = "\\b(?=\\w*(\(theText)))\\w+\\b"
                switch gridViewOptions.matchOption {
                case WordSearchOptions.string.rawValue:
                    print("") // This is the default, nothing to do
                case WordSearchOptions.anyLetter.rawValue:
                    pattern = "\\b(?=\\w*\(groups))\\w+\\b"
                case WordSearchOptions.anyUnicode.rawValue:
                    pattern = "\\b(?=\\w*[\(theText)])\\w+\\b"
                    /*
                case WordSearchOptions.onlyLetters.rawValue:
                    // TODO: Figure out how to search for this
                    print("NOT IMPLEMENTED") */
                case WordSearchOptions.onlyUnicodes.rawValue:
                    pattern = "\\b[\(theText)]+\\b(?![,])"
                default:
                    print("") // Nothing to do here either
                }
                
                let results = matches(regex: pattern, in: contents)
                                
                if results.count > 0 {
                    selectWords(fromArray: results, defWordLen: 5)
                }

            } catch {
                print("Could not load contents of file: \(filepath)")
                hbGridItems.removeAll()
            }
        } else {
            print("The text file \(filename) can't be found in the bundle")
            hbGridItems.removeAll()
        }
    }
    
    func matches( regex: String, in text: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: text,
                                        range: NSRange(text.startIndex..., in: text))
            
            // Limit to 2000 results
            let limit = results.count >= 1000 ? 1000 : results.count
            let returns = results[0..<limit]
            return returns.map {
                String(text[Range($0.range, in: text)!])
            }
            
            // This one returns all matches
            //return results.map {
            //    String(text[Range($0.range, in: text)!])
            //}
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
    
    func selectWords(fromArray: [String], defWordLen: Int) { //}-> [HBGridItem] {
        let attributes: [NSAttributedString.Key : Any] = [
            .font: hbProject.hbFont1.ctFont!
        ]
        
        // This will be used to compare glyf data
        var fontData1: HBFontData?
        var fontData2: HBFontData?
        if hbProject.hbFont2.fileUrl != nil {
            fontData1 = hbProject.hbFont1.getHBFontData()
            fontData2 = hbProject.hbFont2.getHBFontData()
        }
        
        var maxWidth: CGFloat = 0
        
        // Set the flag so the UI will show the spinner
        gridViewOptions.runningComparisons = true
        
        // This is a long comparison, run it in the background
        DispatchQueue.global(qos: .background).async {
            var selections = [HBGridItem]()
            for word in fromArray {
                if word.count < max(defWordLen, theText.count * 3) {
                    //print("Word: \(word) has \(word.count) chars vs \(theText.count) chars")
                    let width = max(100, word.size(withAttributes: attributes).width)
                    maxWidth = max(width, maxWidth)
                    var item = HBGridItem(type:HBGridItemItemType.Word, text:word)
                    
                    let sld1 = hbProject.hbFont1.getStringLayoutData(forText: word)
                    item.width[0] = (sld1.width)
                    
                    // If there are two fonts, see if we have a diff
                    if gridViewOptions.compareWordLayout {
                        if hbProject.hbFont2.fileUrl != nil { //} .filePath.count > 0 {
                            let sld2 = hbProject.hbFont2.getStringLayoutData(forText: word)
                            item.width[1] = sld2.width
                            item.diffWidth = abs(item.width[1] - item.width[0]) > 0.01
                            item.diffLayout = !(sld1 == sld2)
                            // Compare the glyph data of each glyph
                            for hbGlyph in sld1.hbGlyphs {
                                let fd1 = fontData1!.getGlyfData(forGlyphName: hbGlyph.name)
                                let fd2 = fontData2!.getGlyfData(forGlyphName: hbGlyph.name)
                                if fd1!.glyf != fd2!.glyf {
                                    item.diffGlyf = true
                                    break
                                }
                            }
                        }
                    }
                    
                    // Update a local array
                    selections.append(item)
                    if selections.count > 1000 {
                        break
                    }
                }
            }
            
            // Finally update the actual grid items array in the main tread
            DispatchQueue.main.async {
                hbGridItems = selections
                minCellWidth = CGFloat(Double(maxWidth) * 1.2)
                maxCellWidth = CGFloat(Double(maxWidth) * 1.2)
                gridViewOptions.runningComparisons = false
            }
        }
    }
    
    // MARK: ----- Refresh Numbers
    
    func refreshNumbers() {
        print ("Refreshing items in Numbers tab")
        print ("I need to load numeric data for \(hbProject.hbFont1.selectedScript)-\(hbProject.hbFont1.selectedLanguage)")
        print ("Number of digits to use: \(gridViewOptions.digitsOption)")
        
        let scriptNumbers = clusterViewModel.numbers
        let useLatin = scriptNumbers.count == 0 || hbProject.hbFont1.selectedScript == "Latin"
        
        var minValue = 100
        var maxValue = 999
        
        switch gridViewOptions.digitsOption {
        case NumberOfDigits.one.rawValue:
            minValue = 0
            maxValue = 9
        case NumberOfDigits.two.rawValue:
            minValue = 10
            maxValue = 99
        case NumberOfDigits.three.rawValue:
            minValue = 100
            maxValue = 999
        case NumberOfDigits.four.rawValue:
            minValue = 1000
            maxValue = 9999
        case NumberOfDigits.five.rawValue:
            minValue = 10000
            maxValue = 99999
        case NumberOfDigits.six.rawValue:
            minValue = 100000
            maxValue = 999999
        default:
            print("") // Nothing to do here either
        }
        
        let numRange = maxValue - minValue
        let itemCount = numRange < 200 ? numRange : 200
                
        var numArray = [String]()
        
        if itemCount >= 100 {
            for _ in 0 ..< itemCount {
                var number = String(Int.random(in: minValue ... maxValue))
                if gridViewOptions.showThousand || gridViewOptions.showLakh {
                    number = insertComma(inNumber: number, showLakh: gridViewOptions.showLakh, showThousand: gridViewOptions.showThousand )
                }
                if !useLatin {
                    number = translateNumber(asciiNumber: number, scriptNumbers: scriptNumbers)
                }
                numArray.append( number )
            }
        }
        else {
            for i in minValue ... minValue+itemCount {
                var number = String(i)
                if !useLatin {
                    number = translateNumber(asciiNumber: number, scriptNumbers: scriptNumbers)
                }
                numArray.append( number )
            }
        }
        
        selectWords(fromArray: numArray, defWordLen: 10)
    }
    
    
    func updateNumberItems() {
        for i in 0 ..< hbGridItems.count {
            hbGridItems[i].text = insertComma(inNumber: hbGridItems[i].text!,
                                              showLakh: gridViewOptions.showLakh,
                                              showThousand: gridViewOptions.showThousand)
        }
    }
    
    // MARK: ----- JSON helper
    
    func jsonFrom(font1:HBFont, font2:HBFont, text:String) -> String {
        let data = [
            "font1": font1.fileUrl?.absoluteString ?? "",
            "font2": font2.fileUrl?.absoluteString ?? "",
            "text": text
        ]
        
        let dataInJson = try! JSONEncoder().encode(data)
        return String(data: dataInJson, encoding: .utf8)!
    }
}

// Toggle Left Sidebar
func toggleLeftSidebar() {
    NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
}
