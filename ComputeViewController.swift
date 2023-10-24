//
//  ComputeViewController.swift
//  japanShopping
//
//  Created by 沈庭鋒 on 2023/5/21.
// 完成基本功能，待加拍照、即時匯率。
/*
    待修改功能：
    信用卡剩餘回饋金額 // 使用文字 list.payType == "信用卡" 無法正常做判定，理由未知，先用使否出現信用卡選項做判定。

    從 List 按下 done 後清空畫面
 */

import UIKit

class ComputeViewController: UIViewController {

    
    @IBOutlet weak var yenTextField: UITextField!
    
    @IBOutlet weak var taxChoose: UISegmentedControl!
    
    @IBOutlet weak var resultLabel: UILabel!
    
    @IBOutlet weak var exchangeRateLabel: UILabel!
    
    @IBOutlet weak var updateDate: UILabel!
    
    var list = List(productName: "", price : 0, payType: "", taxState: "")
    
    var twdNoTax : Double = 0
    var twdTax : Double = 0
    
    var JYPToTWD = 0.0
        
    override func viewDidLoad() {
        super.viewDidLoad()
        //點空白處收鍵盤
        let tapGesture = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing(_:)))
        view.addGestureRecognizer(tapGesture)
        fectch()
    }
    
    @IBAction func computeButton(_ sender: Any) {
        yenTextField.resignFirstResponder()

        if let yenTextField = yenTextField.text{
            if taxChoose.selectedSegmentIndex == 0{
                twdNoTax = ((Double(yenTextField) ?? 0)*JYPToTWD).rounded()
                twdTax = (twdNoTax*1.08).rounded()
                resultLabel.text = "台幣 \n未稅：\(twdNoTax)\n含稅：\(twdTax)"
            }else if taxChoose.selectedSegmentIndex == 1{
                twdTax = ((Double(yenTextField) ?? 0)*JYPToTWD).rounded()
                twdNoTax = (twdTax/1.08).rounded()
                resultLabel.text = "台幣 \n未稅：\(twdNoTax)\n含稅：\(twdTax)"

            }
        }
    }

    @IBAction func nextPageButtton(_ sender: UIButton) {
        if sender.tag == 1{
            list.price = twdNoTax
            list.taxState = "未稅"
        }else if sender.tag == 2{
            list.price = twdTax
            list.taxState = "含稅"
        }
        nextPage()
    }
    

    func nextPage(){

        if let controller = storyboard?.instantiateViewController(withIdentifier: "DetailViewController") as? DetailViewController{
            if yenTextField.text != ""{
                controller.list = list
                navigationController?.pushViewController(controller, animated: true)
            }
        }
    }
    
    
    // 下載即時匯率的 JSON 資料
    func fectch(){
        let apiKey = ApiManager.shared.apiKey
        guard let key = apiKey, !key.isEmpty else {
            print("API key does not exist")
            return
        }
        let baseURL = "https://v6.exchangerate-api.com/v6/\(key)/latest/USD"
        if let url = URL(string: baseURL){
            let request = URLRequest(url: url)
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let data = data{
                    do {
                        let result = try JSONDecoder().decode(ExchangeRate.self, from: data)
                        let Rate = result.conversion_rates.TWD / result.conversion_rates.JPY
                        //ＧＰＴ提供的變相取進位數的方法，簡單暴力，好用！
                        self.JYPToTWD = (Rate * 10000).rounded() / 10000
                        
                        //以下將更新日期下載並轉圜為台灣地區時區

                        let dateString = result.time_last_update_utc

                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "E, d MMM yyyy HH:mm:ss Z"
                        dateFormatter.locale = Locale(identifier: "en_US_POSIX")  // 設置日期格式的語言環境
                        let date = dateFormatter.date(from: dateString)

                        // 轉換為台灣時區
                        let taiwanTimeZone = TimeZone(identifier: "Asia/Taipei")
                        dateFormatter.timeZone = taiwanTimeZone

                        // 格式化日期為文字
                        dateFormatter.dateFormat = "E, d MMM yyyy HH:mm:ss"
                        let taiwanDateStr = dateFormatter.string(from: date!)

                        // 解析資料完成後畫面更新
                        DispatchQueue.main.async {
                            self.exchangeRateLabel.text = "匯率：\(self.JYPToTWD)"
                            self.updateDate.text = "匯率更新於：\(taiwanDateStr)"

                        }
//                        print(content)
                    } catch  {
                        print(error)

                    }
                }
                
            }.resume()
        }
    }
    
}



