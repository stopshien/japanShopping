//
//  EditCardsTableViewController.swift
//  japanShopping
//
//  Created by 沈庭鋒 on 2023/5/29.
//

import UIKit

class EditCardsTableViewController: UITableViewController {

    var cards = [Card]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
    }

    @IBAction func editFinishButton(_ sender: Any) {
    }
    
    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cards.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "editCardsCell", for: indexPath)

        cell.textLabel?.text = cards[indexPath.row].name
        cell.detailTextLabel?.text = "回饋趴數：\(cards[indexPath.row].percent)％"
        return cell
    }
    
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        cards.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }


    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
       
        if let controller = segue.destination as? DetailViewController{
            controller.cards = cards
        }
    }
    

}
