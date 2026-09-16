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
    
    static let documentDirectory = DocumentsDirectory.url
    
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
