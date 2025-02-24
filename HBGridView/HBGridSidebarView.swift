//
//  WordSearchOptions.swift
//
//  Created by Muthu Nedumaran on 2/3/21.
//

import Combine
import SwiftUI
import AppKit

enum WordSearchOptions: String {
    case string = "Contain string"
    case anyLetter = "Contain any letter in string"
    case anyUnicode = "Contain any unicode in string"
    //case onlyLetters = "Contain only letters in string"
    case onlyUnicodes = "Contain only unicodes in string"
}

enum NumberOfDigits: String {
    case one    = "One"
    case two    = "Two"
    case three  = "Three"
    case four   = "Four"
    case five   = "Five"
    case six    = "Six"
}

struct HBGridSidebarView: View {
    @EnvironmentObject var hbProject: HBProject
    
    @ObservedObject var gridViewOptions: HBGridViewOptions
    @ObservedObject var clusterViewModel: HBGridSidebarClusterViewModel
    @ObservedObject var searchOptions = RadioItems()
    @ObservedObject var digitOptions = RadioItems()


    init(gridViewOptions: HBGridViewOptions, clusterViewModel: HBGridSidebarClusterViewModel) {
        self.gridViewOptions    = gridViewOptions
        self.clusterViewModel   = clusterViewModel
        
        self.searchOptions.labels = [WordSearchOptions.string.rawValue,
                                WordSearchOptions.anyLetter.rawValue,
                                WordSearchOptions.anyUnicode.rawValue,
                                WordSearchOptions.onlyUnicodes.rawValue
        ]
        
        self.digitOptions.labels = [NumberOfDigits.one.rawValue,
                                    NumberOfDigits.two.rawValue,
                                    NumberOfDigits.three.rawValue,
                                    NumberOfDigits.four.rawValue,
                                    NumberOfDigits.five.rawValue,
                                    NumberOfDigits.six.rawValue
        ]
    }

    var body: some View {
        TabView(selection: $gridViewOptions.currentTab) {
            
            // ----------------------------------------
            // Fonts Tab
            // ----------------------------------------
            HStack (alignment: .top) {
                VStack(alignment: .leading) {
                    HBSidebarFont()
                    Spacer()
                    Divider()
                    if hbProject.hbFont2.available {
                        GridDisplayOptionsView(gridViewOptions: gridViewOptions)
                    }
                    
                }
            }
            .tabItem {
                HStack {
                    Text("Fonts")
                }
            }
            .tag(HBGridViewTab.FontsTab)
            .padding(.vertical, 20)
            
            // ----------------------------------------
            // Clusters Tab
            // ----------------------------------------
            
            HStack (alignment: .top) {
                VStack(alignment: .leading) {
                    if hbProject.hbFont1.available {
                        HBSidebarLanguage()
                    }
                    else {
                        Text("Load a font to select script and language")
                            .padding(.leading, 20)
                    }
                    
                    Divider()
                    
                    if hbProject.hbFont1.available {
                        HBGridSidebarCluster(viewModel: clusterViewModel)
                    }
                    
                    Spacer()
                    Divider()
                    
                    GridDisplayOptionsView(gridViewOptions: gridViewOptions)
                }
            }
            .tabItem {
                HStack {
                    Text("Clusters")
                }
            }
            .tag(HBGridViewTab.ClustersTab)
            .padding(.vertical, 20)
            
            // ----------------------------------------
            // The Words Tab
            // ----------------------------------------
            
            HStack (alignment: .top) {
                VStack(alignment: .leading) {
                    if hbProject.hbFont1.available {
                        HBSidebarLanguage(showDefaultLanguage: true)
                        Divider()
                        VStack(alignment: .leading) {
                            if gridViewOptions.wordlistAvailable {
                                Text("Search for words that:")
                                    .multilineTextAlignment(.leading)
                                    .padding(.top, 20)
                                    .padding(.bottom, 10)
                                    .padding(.leading, 20)
                                
                                RadioGroup(callback: { selected in
                                    print("Selected options is: \(selected)")
                                    gridViewOptions.matchOption = selected
                                }, selection: gridViewOptions.matchOption, options: searchOptions)
                                .padding(.bottom, 20)
                                Spacer()
                                Divider()
                                
                                GridDisplayOptionsView(gridViewOptions: gridViewOptions)
                            } else {
                                Text("Word list not available for selected script and language.")
                                    .padding(.top, 20)
                                    .padding(.bottom, 10)
                                    .padding(.horizontal, 20)
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                        
                    }
                    else {
                        Text("Load a font to select script and language")
                    }
                }
            }
            .tabItem {
                HStack {
                    Text("Words")
                }
            }
            .tag(HBGridViewTab.WordsTab)
            .padding(.vertical, 20)
            
            // ----------------------------------------
            // The Numbers Tab
            // ----------------------------------------
            
            HStack (alignment: .top) {
                VStack(alignment: .leading) {
                    if hbProject.hbFont1.available {
                        HBSidebarLanguage(showDefaultLanguage: true)
                        Divider()
                        VStack(alignment: .leading) {
                            Text("Number of digits:")
                                .multilineTextAlignment(.leading)
                                .padding(.top, 20)
                                .padding(.bottom, 10)
                                .padding(.leading, 20)
                            
                            RadioGroup(callback: { selected in
                                print("Number of digits is: \(selected)")
                                gridViewOptions.digitsOption = selected
                            }, selection: gridViewOptions.digitsOption, options: digitOptions)
                            .padding(.bottom, 20)

                            Divider()

                            Toggle("Show thousand", isOn: $gridViewOptions.showThousand)
                                .padding(.top, 20)
                                .padding(.bottom, 10)
                                .padding(.leading, 20)
                            
                            if clusterViewModel.usesLakh {
                                Toggle("Show lakh", isOn: $gridViewOptions.showLakh)
                                    .padding(.bottom, 10)
                                    .padding(.leading, 20)
                            }
                            
                            Spacer()
                            Divider()
                            
                            GridDisplayOptionsView(gridViewOptions: gridViewOptions)
                        }
                    }
                    else {
                        Text("Load a font to select script and language")
                    }
                }
            }
            .tabItem {
                HStack {
                    Text("Numbers")
                }
            }
            .tag(HBGridViewTab.NumbersTab)
            .padding(.vertical, 20)
        }
        .frame(minWidth: 300, idealWidth: 320, maxWidth: 340)
    }
}


struct GridDisplayOptionsView: View {
    @EnvironmentObject var hbProject: HBProject
    @ObservedObject var gridViewOptions:HBGridViewOptions
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Display options:")
                .padding(.bottom, 10)
            
            if gridViewOptions.currentTab == HBGridViewTab.ClustersTab && hbProject.hbFont2.available { //} hbProject.hbFont2.fileUrl == nil {
                HStack {
                    Toggle("Color glyphs", isOn: $gridViewOptions.colorGlyphs)
                        .padding(.bottom, 10)
                }
            }
            
            if hbProject.hbFont2.available { 
                if gridViewOptions.currentTab == HBGridViewTab.WordsTab {
                    HStack {
                        Toggle("Compare layout", isOn: $gridViewOptions.compareWordLayout)
                            .padding(.bottom, 10)
                        if gridViewOptions.runningComparisons {
                            LoadAnimation()
                                .frame(width: 20, height: 20, alignment: .trailing)
                                .padding(.top, -10)
                        }
                    }
                }
            
                Toggle("Show differences only", isOn: $gridViewOptions.showDiffsOnly)
                    .padding(.bottom, 10)
                    .disabled(!gridViewOptions.compareWordLayout && gridViewOptions.currentTab == HBGridViewTab.WordsTab)
            }
        }
        .padding(.leading, 15)
        .padding(.top, 10)
        .padding(.bottom,  40)
    }
}
