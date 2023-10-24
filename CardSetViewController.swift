//
//  CardSetViewController.swift
//  japanShopping
//
//  Created by 沈庭鋒 on 2023/5/22.
//

import UIKit

class CardSetViewController: UIViewController {

    var card : Card?
    
    @IBOutlet weak var cardNameTextField: UITextField!
    
    @IBOutlet weak var moneyBackTextField: UITextField!
    
    @IBOutlet weak var limitTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        //點空白處收鍵盤
        let tapGesture = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing(_:)))
        view.addGestureRecognizer(tapGesture)
    }
    
    @IBAction func addNewCardButton(_ sender: Any) {
        guard let cardName = cardNameTextField.text,
              let moneyBack = moneyBackTextField.text,
              let limit = limitTextField.text else{return}
        if cardName != "",moneyBack != "", limit != ""{
            card = Card(name: cardName, percent: Double(moneyBack)!, limit: Double(limit)!, feedbackRemaining: Double(limit)!)
        }
        
        
    }
    


}
