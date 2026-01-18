// ios/ShareExtension/ShareViewController.swift
// iOS Share Extension for saving URLs to Readwise

import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {
    
    private var sharedUrl: String?
    
    override func isContentValid() -> Bool {
        // Return true if we have a URL to share
        return sharedUrl != nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure appearance
        navigationController?.navigationBar.tintColor = UIColor(red: 99/255, green: 102/255, blue: 241/255, alpha: 1)
        
        // Extract URL from shared content
        extractUrl()
    }
    
    private func extractUrl() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            return
        }
        
        for attachment in attachments {
            // Try URL type first
            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] data, error in
                    if let url = data as? URL {
                        self?.sharedUrl = url.absoluteString
                        DispatchQueue.main.async {
                            self?.validateContent()
                        }
                    }
                }
                return
            }
            
            // Try plain text (might contain URL)
            if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] data, error in
                    if let text = data as? String {
                        // Extract URL from text
                        if let url = self?.extractUrlFromText(text) {
                            self?.sharedUrl = url
                            DispatchQueue.main.async {
                                self?.validateContent()
                            }
                        }
                    }
                }
                return
            }
        }
    }
    
    private func extractUrlFromText(_ text: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        if let match = matches?.first,
           let range = Range(match.range, in: text) {
            return String(text[range])
        }
        
        return nil
    }
    
    override func didSelectPost() {
        guard let url = sharedUrl else {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }
        
        // Save URL to shared UserDefaults (App Group)
        saveUrlToAppGroup(url)
        
        // Optionally send directly to Supabase if we have credentials
        // For MVP, we'll rely on the main app to sync
        
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    private func saveUrlToAppGroup(_ url: String) {
        // Use App Groups to share data with main app
        guard let userDefaults = UserDefaults(suiteName: "group.com.readwise.app") else {
            return
        }
        
        // Get existing pending URLs
        var pendingUrls = userDefaults.stringArray(forKey: "pendingUrls") ?? []
        
        // Add new URL
        pendingUrls.append(url)
        
        // Save back
        userDefaults.set(pendingUrls, forKey: "pendingUrls")
        userDefaults.synchronize()
    }
    
    override func configurationItems() -> [Any]! {
        // Add configuration items if needed (e.g., folder selection)
        return []
    }
}
