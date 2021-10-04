//------------------------------------------------------------------------------
//  UAView.swift
//------------------------------------------------------------------------------
import Cocoa
//------------------------------------------------------------------------------
// 分割イメージ構造体
//------------------------------------------------------------------------------
struct ImagePart{
    var cgImage: CGImage?   //イメージオブジェクト
    var imageRect: CGRect   //分割イメージのロケーションとサイズ
    var dispRect: CGRect    //表示イメージのロケーション（Y軸反転のため）
    
    var hit: Bool
}
//------------------------------------------------------------------------------f
// クラス定義
//------------------------------------------------------------------------------
class UAView: NSView {
    var cgImage: CGImage? = nil             //ファイルから読み込んだ画像
    var currentContext: CGContext? = nil    //ビューのコンテキスト
    var imagePartList = [ImagePart]()       //分割イメージリスト
    var newImage: CGImage? = nil            //サイズ正規化後のイメージ
    //分割数
    var xNum: Int = 20
    var yNum: Int  = 20
    //タイマーオブジェクト
    var timer: Timer? = nil
    //測定
    var startTime :Date = Date()
    var endTime :Date = Date()
    var elapsTime: Double = 0
    @objc var elaps: Double = 0{
        willSet {self.willChangeValue(forKey: "elaps")}
        didSet {self.didChangeValue(forKey: "elaps")}
    }
    @objc var trialCount: Int = 0{
        willSet {self.willChangeValue(forKey: "trialCount")}
        didSet {self.didChangeValue(forKey: "trialCount")}
    }
    //状態
    enum Status{
        case none           //初期状態
        case arranged       //配置済み
        case running        //実行中
        case complete       //完了
    }
    //--------------------------------------------------------------------------
    //状態の遷移:それに伴う処理
    //--------------------------------------------------------------------------
    var status: Status = .none{
        didSet {
            let appDelegate = NSApplication.shared.delegate as! AppDelegate
            if status == .arranged{
                //配置済み
                if oldValue == .none || oldValue == .complete{
                    elapsTime = 0; elaps = 0; trialCount = 0
                    self.arrange() //ランダム配置
                }else{ //.running
                    //実行中のときはタイマーを停止する
                    self.timer?.invalidate() //タイマー停止
                }
                appDelegate.startBtn.title = "Start"
            }
            else if status == .running{
                //実行中
                startTime = Date()
                //タイマー起動
                self.timer = Timer.scheduledTimer(timeInterval: 0.01,
                                                  target: self,
                                                  selector: #selector(arrange),
                                                  userInfo: nil,
                                                  repeats: true)
                appDelegate.startBtn.title = "Stop"
            }
            else if status == .complete{
                //整列完了
                self.timer?.invalidate()            //タイマー停止
                self.outputLog()                    //ログ出力
                for i in 0 ..< imagePartList.count{ //分割イメージリストの初期化
                    imagePartList[i].hit = false
                }
                appDelegate.startBtn.title = "もう一度"
            }
        }
    }
    //--------------------------------------------------------------------------
    //オブジェクトの初期化時
    //--------------------------------------------------------------------------
    override func awakeFromNib() {
        self.wantsLayer = true
        self.layer?.borderWidth = 1.0
    }
    //--------------------------------------------------------------------------
    // ボタンのクリック
    //--------------------------------------------------------------------------
    func goStop(){
        if self.status == .complete{
            //もう一度
            self.status = .arranged
        }
        else if self.status == .arranged{
            //開始
            self.status = .running
        }
        else if self.status == .running{
            //停止
            self.status = .arranged
        }
    }
    //--------------------------------------------------------------------------
    //イメージの分割
    //--------------------------------------------------------------------------
    func resizeImage(_ image: CGImage){
        //******************
        self.status = .none
        //******************
        //ビューサイズ
        let maxWidth: CGFloat = 800
        let maxHeight: CGFloat = 600
        var xAdjust: CGFloat = 0
        var yAdjust: CGFloat = 0
        //イメージの正規化後のサイズ
        var newSize = CGSize.init(width: 0, height: 0)
        if ( CGFloat(image.height) / CGFloat(image.width) < maxHeight / maxWidth) {
            //横長・上下に余白
            newSize.width = maxWidth
            newSize.height = floor(maxWidth * CGFloat(image.height) / CGFloat(image.width))
            yAdjust = floor((maxHeight - newSize.height) / 2) //余白
        }else{
            //縦長。左右に余白
            newSize.width = floor(maxHeight * CGFloat(image.width) / CGFloat(image.height))
            newSize.height = maxHeight
            xAdjust = floor((maxWidth - newSize.width) / 2) //余白
        }
        //読み込んだイメージを正規化サイズに縮小または拡大する。
        let imageColorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        let newContext = CGContext.init(data: nil,
                                        width: Int(newSize.width),
                                        height: Int(newSize.height),
                                        bitsPerComponent: 8,
                                        bytesPerRow: Int(newSize.width) * 4,
                                        space: imageColorSpace!,
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        newContext?.draw(image,
                         in: CGRect.init(x: 0, y: 0,
                                         width: newSize.width,height: newSize.height))
        newImage = newContext!.makeImage() //作成したイメージをプロパティに保持する
        //分割後のイメージの幅＆高さ
        var xlengths = [Int](repeating: 0, count: xNum)
        var ylengths = [Int](repeating: 0, count: yNum)
        //分割部分の幅を求める（1ピクセルづつ配分する）
        var index = 0
        for _ in 1 ... Int(newSize.width){
            xlengths[index] += 1
            if index == xNum - 1{
                index = 0
            }else{
                index += 1
            }
        }
        //分割部分の高さを求める（1ピクセルづつ配分する）
        index = 0
        for _ in 1 ... Int(newSize.height){
            ylengths[index] += 1
            if index == yNum - 1{
                index = 0
            }else{
                index += 1
            }
        }
        //分割イメージリストを作成する
        self.imagePartList = [ImagePart]()  //初期化
        var yPos = 0
        for i in 0 ..< yNum{
            var xPos = 0
            for j in 0 ..< xNum{
                //位置とサイズ
                let imageRect = CGRect.init(x: xPos, y: yPos,
                                       width: xlengths[j], height: ylengths[i])
                var dispRect = imageRect
                dispRect.origin.x += xAdjust
                dispRect.origin.y = newSize.height - CGFloat(yPos + ylengths[i]) //Y軸は上下反転する
                dispRect.origin.y += yAdjust
                imagePartList.append(ImagePart.init(cgImage: nil,
                                                    imageRect: imageRect,
                                                    dispRect: dispRect,
                                                    hit: false))
                xPos += xlengths[j]
            }
            yPos += ylengths[i]
        }
        print(String(format:"%.0fx%.0f", newSize.width, newSize.height))
        print("imageRect")
        _ = self.imagePartList.map{
            print(String(format:"%.0f:%.0f %.0fx%.0f",
                         $0.imageRect.origin.x, $0.imageRect.origin.y,
                         $0.imageRect.size.width, $0.imageRect.size.height))
        }
        print("dispRect")
        _ = self.imagePartList.map{
            print(String(format:"%.0f:%.0f %.0fx%.0f",
                         $0.dispRect.origin.x, $0.dispRect.origin.y,
                         $0.dispRect.size.width, $0.dispRect.size.height))
        }
        //**********************
        self.status = .arranged
        //**********************
    }
    //--------------------------------------------------------------------------
    // 分割イメージのランダム配置
    //--------------------------------------------------------------------------
    @objc private func arrange(){
        //分割イメージが全て正しい位置に配置されたら終了
        if imagePartList.filter({$0.hit == true}).count == imagePartList.count{
            //**********************
            self.status = .complete
            //**********************
            return
        }
        //分割イメージの再配置
        for i in 0 ..< imagePartList.count{
            if imagePartList[i].hit == true{
                //配置済みのフレームは飛ばす
                continue
            }
            while(true){
                //乱数の取得
                let num = Int(arc4random_uniform(UInt32(imagePartList.count)))
                /* bad performance, too slow
                let result = imagePartList.enumerated().filter(
                             {$0.offset == num && $0.element.hit == true}).count
                */
                var result = 0
                for j in 0 ..< imagePartList.count{
                    if j == num && imagePartList[j].hit == true{
                        result = 1
                        break
                    }
                }
                if result ==  0{
                    let target: ImagePart = imagePartList[num]
                    //let target: ImagePart = imagePartList[i]  //整列
                    let rect = CGRect.init(x: target.imageRect.origin.x ,
                                           y: target.imageRect.origin.y,
                                           width: imagePartList[i].imageRect.width,
                                           height: imagePartList[i].imageRect.height)
                    imagePartList[i].cgImage = newImage?.cropping(to: rect)
                    if i == num{
                        imagePartList[i].hit = true
                    }
                    break
                }
            }
        }
        self.needsDisplay = true
        //途中経過
        if self.status == .running{
            endTime = Date()
            self.elapsTime += endTime.timeIntervalSince(startTime)
            self.elaps = round(self.elapsTime*100)/100 //経過秒数
            startTime = Date()
            self.trialCount += 1 //試行回数
        }
    }
    //--------------------------------------------------------------------------
    //ビューの再表示
    //--------------------------------------------------------------------------
    override func draw(_ dirtyRect: NSRect) {
        if imagePartList.count == 0{
            return
        }
        if let context = NSGraphicsContext.current?.cgContext{
            for imagePart in imagePartList{
                if imagePart.cgImage != nil{
                    context.draw(imagePart.cgImage! , in: imagePart.dispRect)
                }
            }
        }
    }
    //--------------------------------------------------------------------------
    // ログ出力
    //--------------------------------------------------------------------------
    private func outputLog(){
        let ft = DateFormatter()
        ft.dateStyle = .short
        ft.timeStyle = .short
        //日付時刻、処理時間（秒）、試行回数、分割数（x, y）
        let log = String(format:"%@ GraphicQuize: %.2f秒 %ld回 分割数%ldx%ld performance %.4f秒/回\n",
                         ft.string(from: self.endTime),
                         self.elaps, self.trialCount,
                         self.xNum, self.yNum,
                         self.elaps / Double(self.trialCount))
        guard let data = log.data(using: String.Encoding.utf8) else {
            print("couuld not create log data")
            return
        }
        let url = URL.init(fileURLWithPath:NSHomeDirectory() + "/Pictures/GraphicQuize.txt")
        if FileManager.default.fileExists(atPath:url.path) == false{
            let ret = FileManager.default.createFile(atPath: url.path,
                                                     contents: "".data(using: .utf8),
                                                     attributes: nil)
            if ret == false{
                print("\(url.path)  couuld not create")
                return
            }
        }
        if let fh = try? FileHandle(forWritingTo: url){
            fh.seekToEndOfFile()
            fh.write(data)
            fh.closeFile()
        }else{
            print("\(url.path)  couuld not write")
            return
        }
    }
}

