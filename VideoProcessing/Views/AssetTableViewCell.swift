//
//  AssetTableViewCell.swift
//  VideoProcessing
//
//  Created by Monkey on 11/20/16.
//  Copyright © 2016 Monkey. All rights reserved.
//

import UIKit

class AssetTableViewCell: UITableViewCell {
    
    @IBOutlet var lblOrderNumber: UILabel!
    @IBOutlet var txtDurationOfPhoto: UITextField!
    @IBOutlet var lblMediaType: UILabel!
    @IBOutlet var lblDurationSecond: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
