import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            WritingView()
                .tabItem {
                    Label("写作", systemImage: "book.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
        }
    }
}

#Preview {
    ContentView()
} 
