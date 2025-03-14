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
            ZStack {
                // 背景色
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // 基本信息部分
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "book")
                                    .foregroundColor(AppTheme.primary)
                                Text("基本信息")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.text)
                            }
                            .padding(.horizontal)
                            
                            VStack(alignment: .leading, spacing: 20) {
                                // 书籍名称
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("书籍名称")
                                        .font(.subheadline)
                                        .foregroundColor(AppTheme.secondaryText)
                                    
                                    TextField("请输入书籍名称", text: $bookTitle)
                                        .focused($focusedField, equals: .title)
                                        .textInputAutocapitalization(.never)
                                        .submitLabel(.next)
                                        .onSubmit {
                                            focusedField = .description
                                        }
                                        .padding(12)
                                        .background(AppTheme.cardBackground)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(AppTheme.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                }
                                
                                // 书籍简介
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("书籍简介")
                                        .font(.subheadline)
                                        .foregroundColor(AppTheme.secondaryText)
                                    
                                    TextField("请输入书籍简介", text: $bookDescription, axis: .vertical)
                                        .focused($focusedField, equals: .description)
                                        .textInputAutocapitalization(.never)
                                        .lineLimit(3...6)
                                        .padding(12)
                                        .background(AppTheme.cardBackground)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(AppTheme.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("新建书籍")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.secondaryText)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        viewModel.addBook(title: bookTitle, description: "")
                        dismiss()
                    }
                    .foregroundColor(bookTitle.isEmpty ? AppTheme.secondaryText.opacity(0.5) : AppTheme.primary)
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