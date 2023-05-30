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

    @IBOutlet weak var priceLabel: UILabel!
    
    @IBOutlet weak var productTextField: UITextField!
    
    @IBOutlet weak var payTypePicker: UIPickerView!
        
    @IBOutlet weak var cardsChooseOutlet: UIButton!
    
    @IBOutlet weak var feedbackLabel: UILabel!
    
    @IBOutlet weak var editCardsButtonOutlet: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        payTypePicker.delegate = self
        payTypePicker.dataSource = self
        
        // 一進到畫面先讀取cards 資料
        if let readCards = Card.readCards(){
            cards = readCards
        }
        
        // 讀取 List 檔案
        if let readList = List.readList(){
            lists = readList
        }
        UISet()
    }
    
    // 從其他頁面倒退回到 DetailViewController 這個頁面的時候會做的事情。
    @IBAction func unwindToCardVSetViewController(_ unwindSegue: UIStoryboardSegue) {
        
        // 若是從 CardSetViewController 倒退回來的話會執行下列動作
        if let sourceViewController = unwindSegue.source as? CardSetViewController,
           let card = sourceViewController.card{
            cards.append(card)

        }
        // 不管從哪裡回來都會執行這些動作
        cardChooseButtonSet()
        Card.saveCards(cards: cards)
        print(cards)
    }
    
    @IBAction func saveToListButton(_ sender: Any) {
        // 在儲存到 List 頁面前需要先計算回饋的金額以及回饋上限剩下多少，並且記錄到 cards 的矩陣資料中。
        // 回饋剩餘金額獨立建立一個變數，並且在 CardSetViewController 設定 limit 時賦予設定初始數值。
        // 需要判斷使用現金還是信用卡，因為現金無法執行 cards 屬性的使用，會崩潰。
    
        if list.payType == "信用卡"{
            // 不能沒選信用卡就按確認存到List，不然沒辦法跑下面這行，會崩潰。
            if numberOfCards > -1{
                cards[numberOfCards].feedbackRemaining = cards[numberOfCards].limit - cards[numberOfCards].feedbackMoney
                Card.saveCards(cards: cards)
                print(cards)
            }
        }
        saveToList()

    }
    
    @IBAction func cardChoose(_ sender: Any) {
        //下拉按鈕的action 還沒用到，設定在outlet那邊
    }
    
    
    @IBAction func editCardsButton(_ sender: Any) {
        if let controller = storyboard?.instantiateViewController(withIdentifier: "\(EditCardsTableViewController.self)") as? EditCardsTableViewController {
            navigationController?.pushViewController(controller, animated: true)
            controller.cards = cards
        }
    }
    
    
    //將購買的商品儲存到清單中
    func saveToList(){
        if productTextField.text != ""{
            list.productName = productTextField.text ?? ""
            if let controller = storyboard?.instantiateViewController(withIdentifier: "ListViewController") as? ListViewController{
                lists.append(list)
                controller.lists = lists
                // 按下儲存至List清單的按鈕時會順便儲存檔案
                List.saveList(list: controller.lists)
                navigationController?.pushViewController(controller, animated: true)
            }
        }
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
        
        var cardsArray = [UIAction(title: "新增信用卡", handler: { _ in
            if let controller = self.storyboard?.instantiateViewController(withIdentifier: "CardSetViewController") as? CardSetViewController{
                self.navigationController?.pushViewController(controller, animated: true)
            }
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
