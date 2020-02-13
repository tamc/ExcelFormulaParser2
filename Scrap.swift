//
//  Scrap.swift
//
//
//  Created by Thomas Counsell on 13/02/2020.
//

import Foundation

Optional(.table("DeptSales", .structured(.union([.ref("#All"), .ref("Sales Amount")]))))
