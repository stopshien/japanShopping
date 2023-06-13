//
//  List.swift
//  japanShopping
//
//  Created by 沈庭鋒 on 2023/5/21.
//

import Foundation

struct List:Codable{
    var productName : String
    var price : Double
//    let taxPrice : Double
    var payType: String 
    var taxState : String
    var photoURL : String?
    
    static let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    // list 的存檔
    static func saveList(list:[Self]){
        let encoder = PropertyListEncoder()
        if let data = try? encoder.encode(list){
            let url = documentDirectory.appendingPathComponent("list")
            try? data.write(to: url)
         }
    }
    
    //list 的讀取
    static func readList() -> [Self]?{
        let decoder = PropertyListDecoder()
        let url = documentDirectory.appendingPathComponent("list")
        if let data = try? Data(contentsOf: url),
           let list = try? decoder.decode([List].self, from: data){
            return list
        }else{
            return nil
        }

    }


}

struct Card:Codable{
    let name: String
    let percent : Double
    let limit : Double
    var feedbackMoney = 0.0
    var feedbackRemaining = 0.0
    
    static let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    // 儲存信用卡資料
    static func saveCards(cards:[Self]){
        let encoder = PropertyListEncoder()
        if let data = try? encoder.encode(cards){
            let url = documentDirectory.appendingPathComponent("cards")
            try? data.write(to: url)
        }
    }
    
    // 讀取信用卡資料
    static func readCards() -> [Self]?{
            let url = documentDirectory.appendingPathComponent("cards")
            let decoder = PropertyListDecoder()
        if let data = try? Data(contentsOf: url),
           let cards = try? decoder.decode([Card].self, from: data){
            return cards
        }else{
            return nil
        }
        
    }
    

}
