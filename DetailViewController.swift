//
//  DetailViewController.swift
//  japanShopping
//
//  Created by 沈庭鋒 on 2023/5/21.
//

import UIKit

class DetailViewController: UIViewController {

    var list = List(productName: "", price: 0, payType: "", taxState: "")
    var lists = [List]()
    var cards = [Card]()
    var numberOfCards = -1 // 紀錄選擇哪張信用卡對應到矩陣的順序。

    // 信用卡畫面已遷移至 MVVM，這裡透過 repository 取得資料，
    // 待 DetailViewController 自己遷移後會改為注入。
    private let cardRepository: CardRepository = FileCardRepository()
    var selectPhoto = false // 判定是否有選擇照片

    
    @IBOutlet weak var priceLabel: UILabel!
    
    @IBOutlet weak var productTextField: UITextField!
    
    @IBOutlet weak var payTypePicker: UIPickerView!
        
    @IBOutlet weak var cardsChooseOutlet: UIButton!
    
    @IBOutlet weak var feedbackLabel: UILabel!
    
    @IBOutlet weak var editCardsButtonOutlet: UIButton!
    
    @IBOutlet weak var imageSelectButtonOutlet: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageSelectButtonOutlet.imageView?.contentMode = .scaleAspectFit
        imageSelectButtonOutlet.layer.borderColor = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        imageSelectButtonOutlet.layer.borderWidth = 4
        
        payTypePicker.delegate = self
        payTypePicker.dataSource = self
        
        // 一進到畫面先讀取cards 資料
        reloadCards()
        
        // 讀取 List 檔案
        if let readList = List.readList(){
            lists = readList
        }
        UISet()
    }

    // 信用卡畫面（新增／編輯）返回後重新載入，取代原本的 unwind segue。
    private func reloadCards() {
        do {
            cards = try cardRepository.load()
        } catch {
            cards = []
        }
        // 卡片數量或內容變了，選單與選取索引都必須重建。
        numberOfCards = -1
        cardChooseButtonSet()
    }
    
    @IBAction func saveToListButton(_ sender: Any) {
        // 在儲存到 List 頁面前需要先計算回饋的金額以及回饋上限剩下多少，並且記錄到 cards 的矩陣資料中。
        // 回饋剩餘金額獨立建立一個變數，並且在 CardSetViewController 設定 limit 時賦予設定初始數值。
        // 需要判斷使用現金還是信用卡，因為現金無法執行 cards 屬性的使用，會崩潰。
        // 使用文字 list.payType == "信用卡" 無法正常做判定，理由未知，先用使否出現信用卡選項做判定。
        if cardsChooseOutlet.isHidden == false{
            // 不能沒選信用卡就按確認存到List，不然沒辦法跑下面這行，會崩潰。
            if numberOfCards > -1{
                cards[numberOfCards].feedbackRemaining = cards[numberOfCards].limit - cards[numberOfCards].feedbackMoney
                try? cardRepository.save(cards)
            }
        }
        saveToList()

    }
    
    @IBAction func cardChoose(_ sender: Any) {
        //下拉按鈕的action 還沒用到，設定在outlet那邊
    }
    
    
    @IBAction func editCardsButton(_ sender: Any) {
        let viewModel = CardListViewModel(repository: cardRepository)
        let controller = CardListViewController(viewModel: viewModel)
        controller.onFinish = { [weak self] in
            self?.reloadCards()
        }
        navigationController?.pushViewController(controller, animated: true)
    }
    
    @IBAction func imagePickerButton(_ sender: Any) {
        let imagePickerController = UIImagePickerController()
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.delegate = self
        present(imagePickerController, animated: true, completion: nil)
    }
    
    
    
    //將購買的商品儲存到清單中
    func saveToList(){
        if productTextField.text != ""{
            list.productName = productTextField.text ?? ""
            photoSaveSet()
            if let controller = storyboard?.instantiateViewController(withIdentifier: "ListViewController") as? ListViewController{
                lists.append(list)
                controller.lists = lists
                // 按下儲存至List清單的按鈕時會順便儲存檔案
                List.saveList(list: controller.lists)
                navigationController?.pushViewController(controller, animated: true)
            }
        }
    }
    
    // 設定圖片的轉碼及路徑，最後存進 List 的物件中。
    func photoSaveSet(){
        var imageName: String?
       
        if selectPhoto {

            if imageName == nil {
                imageName = UUID().uuidString
            }
        /*
         使用 image.jpegData(compressionQuality:) 方法將圖片轉換為 JPEG 格式的二進位資料，並將其指派給 imageData 變數。
         */
            let imageData = imageSelectButtonOutlet.image(for: .normal)?.jpegData(compressionQuality: 0.9)
            /*
             使用 FileManager.default.urls(for:in:) 方法獲取 Document Directory 的路徑，並將其指派給 documentsDirectory 變數。
             在 List 那邊有建立 documentDirectory，並使用 appendingPathComponent(_:) 方法將檔案名稱附加到 Document Directory 的路徑中，生成最終的檔案路徑 fileURL。
             使用 imageData.write(to:) 方法將圖片資料寫入指定的檔案路徑中。
             */
            let imageUrl = List.documentDirectory.appendingPathComponent(imageName!).appendingPathExtension("jpg")
            try? imageData?.write(to: imageUrl)
        }
        // 將圖片路徑加入 list 。
        list.photoURL = imageName
    }
    
    // 設定ＵＩ顯示
    func UISet(){
        priceLabel.text = "價格：\(list.price)$ (\(list.taxState))"
        //點擊空白處收鍵盤
        let tapGesture = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing(_:)))
        view.addGestureRecognizer(tapGesture)
        cardChooseButtonSet()
    }
    
    //信用卡選擇下拉式選單功能設定
    func cardChooseButtonSet(){
        
        var cardsArray = [UIAction(title: "新增信用卡", handler: { [weak self] _ in
            guard let self else { return }
            let viewModel = CardSetViewModel(repository: self.cardRepository)
            let controller = CardSetViewController(viewModel: viewModel)
            controller.onFinish = { [weak self] in
                self?.reloadCards()
            }
            self.navigationController?.pushViewController(controller, animated: true)
        })]
        if cards.count > 0{
            for i in 0...cards.count-1{
                let action = UIAction(title: "\(cards[i].name) \(cards[i].percent)%") { _ in
                    self.cardsChooseOutlet.setTitle("\(self.cards[i].name)卡 剩餘\(self.cards[i].feedbackRemaining)元", for: .normal)
                    self.list.payType = self.cards[i].name
                    self.cards[i].feedbackMoney = (self.cards[i].percent - 1.5) * self.list.price * 0.01
                    self.feedbackLabel.text = "回饋金額為：\(String(format: "%.2f", self.cards[i].feedbackMoney))"
                    self.numberOfCards = i
                }
                cardsArray.append(action)
            }
        }
        cardsChooseOutlet.menu = UIMenu(children:cardsArray)

    }
    
}

extension DetailViewController: UIPickerViewDelegate,UIPickerViewDataSource{
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 2
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if row == 0 {
            return "現金"
        }else{
            return "信用卡"
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if row == 0{
            list.payType = "現金"
            cardsChooseOutlet.isHidden = true
            feedbackLabel.isHidden = true
            editCardsButtonOutlet.isHidden = true
        }else{
            list.payType = "信用卡"
            cardsChooseOutlet.isHidden = false
            feedbackLabel.isHidden = false
            editCardsButtonOutlet.isHidden = false
        }
    }
    
}

extension DetailViewController: UIImagePickerControllerDelegate,UINavigationControllerDelegate{
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        selectPhoto = true
        let image = info[.originalImage] as? UIImage
        imageSelectButtonOutlet.setImage(image, for: .normal)

        dismiss(animated: true, completion: nil)
    }
    
}
