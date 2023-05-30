//
//  ListTableViewCell.swift
//  japanShopping
//
//  Created by 沈庭鋒 on 2023/5/21.
//

import UIKit

class ListTableViewCell: UITableViewCell {

    
    @IBOutlet weak var productName: UILabel!
    
    @IBOutlet weak var priceLabel: UILabel!
    
    @IBOutlet weak var TypeOfPay: UILabel!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

    }

}
