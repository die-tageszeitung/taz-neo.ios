//
//  Untitled.swift
//  taz.neo
//
//  Created by Ringo Müller on 17.10.25.
//  Copyright © 2025 taz. All rights reserved.
//

extension GqlFeeder {
  /*
  func getUserDataLastRead(closure: @escaping(Result<GqlLastReadItem?,Error>)->()) {
    guard let gqlSession = self.gqlSession else {
      closure(.failure(fatal("Not connected"))); return
    }
    
    let request = GqlCustomerData.request(category: .global, name: .lastRead)
    
    gqlSession.query(graphql: request, type: [String:GqlCustomerDataWrapper].self) {  (res) in
      guard let response = res.value()?["getCustomerData"] as? GqlCustomerDataWrapper,
            response.customerDataList?.count ?? 2 < 2 else {
        closure(.failure(self.fatal("Unexpected Server Response")))
        return
      }
      //ToDo Process authInfo
      print("requested GqlCustomerData... authInfo: \(response.authInfo)")
      
      closure(.success(response.customerDataList?.first?.decodeItem()))
    }
  }
  
  func saveUserLastRead(item: LastReadItem,
                        closure: @escaping(Result<GqlSaveCustomDataResponseWrapper,Error>)->()) {
    guard let request = item.request else {
      closure(.failure(self.error("No valid Request available")))
      return
    }
    
    guard let gqlSession = self.gqlSession else {
      closure(.failure(fatal("Not connected"))); return
    }
    
    gqlSession.mutation(graphql: request,
                     type: GqlSaveCustomDataResponseWrapper.self) {[weak self] res in
      guard let self = self else { return }
      switch res {
        case .success(let response):
          closure(.success(response))
        case .failure(let err):
          closure(.failure(err))
      }
    }
  }
   */
}
