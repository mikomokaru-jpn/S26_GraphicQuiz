//------------------------------------------------------------------------------
//  AppDelegate.swift
//------------------------------------------------------------------------------
import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var view: UAView!
    @IBOutlet weak var openBtn: NSButton!
    @IBOutlet weak var startBtn: NSButton!
    @IBOutlet weak var triesField: NSTextField!
    @IBOutlet weak var elapsField: NSTextField!
    @IBOutlet weak var xNumField: NSTextField!
    @IBOutlet weak var yNumField: NSTextField!

    //--------------------------------------------------------------------------
    // アプリケーション起動時
    //--------------------------------------------------------------------------
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        startBtn.isEnabled = false
        xNumField.integerValue = 20
        yNumField.integerValue = 20
        startBtn.keyEquivalent = "\r"
    }
    //--------------------------------------------------------------------------
    //開始/停止ボタン
    //--------------------------------------------------------------------------
    @IBAction func start(_ sender: NSButton){
        view.goStop()
    }
    //--------------------------------------------------------------------------
    //オープンパネルからディレクトリを選択する
    //--------------------------------------------------------------------------
    @IBAction func selectFile(_ sender: NSButton){
        let openPanel = NSOpenPanel.init()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.message = "イメージファイルを選択する"
        let url = NSURL.fileURL(withPath: NSHomeDirectory() + "/Pictures")
        //最初に位置付けるディレクトリパス
        openPanel.directoryURL = url
        //オープンパネルを開く
        openPanel.beginSheetModal(for: self.window, completionHandler: { (result) in
            if result == .OK{
                //ディレクトリの選択
                let url: URL = openPanel.urls[0]
                if let cgImageSource = CGImageSourceCreateWithURL(url as CFURL, nil){
                    if let cgImage = CGImageSourceCreateImageAtIndex(cgImageSource, 0, nil){
                        self.view.xNum = self.xNumField.integerValue
                        self.view.yNum = self.yNumField.integerValue
                        self.view.resizeImage(cgImage)
                        self.startBtn.isEnabled = true
                    }
                }
            }
        })
    }
}

