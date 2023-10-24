//
//  ListViewController.swift
//  japanShopping
//
//  Created by 沈庭鋒 on 2023/5/21.
//

import UIKit

class ListViewController: UIViewController {

    @IBOutlet weak var listTableView: UITableView!
    
    @IBOutlet weak var totalSpend: UILabel!
    
    var lists = [List]()
    var totalSpendMoney :Double = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()

        listTableView.delegate = self
        listTableView.dataSource = self
        
        if let readLists = List.readList(){
            lists = readLists
        }
        if lists.isEmpty == false{
            totalSpendCount()
        }
        print(lists)
    }
    
    
    @IBAction func DoneButton(_ sender: Any) {
        navigationController?.popToRootViewController(animated: true)
        List.saveList(list: lists)
    }
    
    func totalSpendCount(){
        for i in 0...lists.count-1{
            totalSpendMoney += lists[i].price
        }
        totalSpend.text = "你已經花了\(totalSpendMoney)$"
    }
    
}

extension ListViewController:UITableViewDelegate,UITableViewDataSource{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return lists.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = listTableView.dequeueReusableCell(withIdentifier: "\(ListTableViewCell.self)", for: indexPath) as! ListTableViewCell
        
            let rowNum = lists[indexPath.row]
            cell.productName.text = rowNum.productName
            cell.priceLabel.text = "\(rowNum.price)$(\(rowNum.taxState))"
            cell.TypeOfPay.text = rowNum.payType
        
        // 設定相片的讀取顯示
        
        if let imageName = lists[indexPath.row].photoURL {
                let imageUrl =  List.documentDirectory.appendingPathComponent(imageName).appendingPathExtension("jpg")
                let image = UIImage(contentsOfFile: imageUrl.path)
                cell.shopPhoto.image = image
            }
        return cell
    }
    
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        lists.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
        //判斷清單矩陣內是否為空，並且在每一次刪除資料時都會重新計算總金額。
        if !lists.isEmpty{
            totalSpendMoney = 0
            totalSpendCount()
        }else{
            totalSpend.text = "你已經花了0$"
        }
        // 刪除功能沒有謢直接儲存，怕刪錯，所以只有按下 done 按鈕才會儲存。
    }

    
    
}
