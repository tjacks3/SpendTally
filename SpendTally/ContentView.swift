//
//  ContentView.swift
//  SpendTally
//
//  Created by Trevan Jackson on 3/15/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "app.translucent")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("SpendTally!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
