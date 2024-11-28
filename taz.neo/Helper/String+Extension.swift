//
//  String+Extension.swift
//  taz.neo
//
//  Created by Ringo Müller on 28.11.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import Foundation

extension String {
  var authorsFormated: String {
#if LMD
    return self.length > 0 ? self.xmlEscaped().prepend("von ") : ""
#else
    return self.xmlEscaped()
#endif
  }
}
