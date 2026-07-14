//
//  VIN.swift
//  OBD2 Scanner
//
//  Created by Trevor Moore on 7/13/26.
//

struct VINResult: Codable {
    let Value: String?
    let ValueId: String?
    let Variable: String
    let VariableId: Int
}

struct VIN: Codable {
    let Count: Int
    let Message: String
    let SearchCriteria: String
    let Results: [VINResult]
}
