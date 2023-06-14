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
    
    var list = List(productName: "", price : 0, payType: "", taxState: "")
    
    var twdNoTax : Double = 0
    var twdTax : Double = 0
        
    override func viewDidLoad() {
        super.viewDidLoad()
        //點空白處收鍵盤
        let tapGesture = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing(_:)))
        view.addGestureRecognizer(tapGesture)
    }
    
    @IBAction func computeButton(_ sender: Any) {
        yenTextField.resignFirstResponder()

        if let yenTextField = yenTextField.text{
            if taxChoose.selectedSegmentIndex == 0{
                twdNoTax = ((Double(yenTextField) ?? 0)*0.225).rounded()
                twdTax = (twdNoTax*1.08).rounded()
                resultLabel.text = "台幣 \n未稅：\(twdNoTax)\n含稅：\(twdTax)"
            }else if taxChoose.selectedSegmentIndex == 1{
                twdTax = ((Double(yenTextField) ?? 0)*0.225).rounded()
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
}
