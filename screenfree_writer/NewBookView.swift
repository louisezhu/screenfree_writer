import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct NewBookView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bookTitle: String = ""
    @State private var bookDescription: String = ""
    @FocusState private var focusedField: Field?
    @ObservedObject var viewModel: BookViewModel
    
    enum Field {
        case title, description
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 基本信息部分
                    VStack(alignment: .leading, spacing: 12) {
                        Text("基本信息")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            TextField("书籍名称", text: $bookTitle)
                                .focused($focusedField, equals: .title)
                                .textInputAutocapitalization(.never)
                                .submitLabel(.next)
                                .onSubmit {
                                    focusedField = .description
                                }
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            TextField("书籍简介", text: $bookDescription, axis: .vertical)
                                .focused($focusedField, equals: .description)
                                .textInputAutocapitalization(.never)
                                .lineLimit(3...6)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 2)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("新建书籍")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        viewModel.addBook(title: bookTitle, description: bookDescription)
                        dismiss()
                    }
                    .disabled(bookTitle.isEmpty)
                }
            }
            .onAppear {
                focusedField = .title
            }
        }
        .frame(minWidth: 400, minHeight: 200)
    }
}

#Preview {
    NewBookView(viewModel: BookViewModel())
} 