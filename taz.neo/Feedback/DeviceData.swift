//
//  DeviceData.swift
//  taz.neo
//
//  Created by Ringo.Mueller on 08.10.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

public struct DeviceData : DoesLog {
  typealias ram = (ramUsed:String?, ramAvailable:String?)
  
  /// Ram used by current App (quite exactly like xCode displayed)
  var ramUsed : String?
  
  /// Free Ram available for App (less than DeviceRam - VM Used)
  var ramAvailable : String?
  
  /// Storage available for ImportantUsage (less than SystemSettings total Free Space)
  var storageAvailable : String?
  
  /// Used Storage by current App (little bit less than Settings->PhoneStorage-> App used->Doc&Data)
  /// Did not contain the App-Size itself
  var storageUsed : String?
  
  init() {
    var _dc:DeviceDataCollect? = DeviceDataCollect()
    if let dc = _dc {
      
      ramAvailable = "\(dc.freeMemory())"
      
      if let used = dc.appUsedRam() {
        ramUsed = "\(used)"
      }
      
      if let free = dc.freeStorage() {
        storageAvailable = "\(free)"
      }
      
      storageUsed = "\(dc.storageUsedByApp())"
    }
    _dc = nil
  }
  
  //Collect Data Helper (to have Log here and no strong References in DeviceData)
  public struct DeviceDataCollect : DoesLog {
    // MARK:  freeMemory
    func freeMemory() -> Int64 {
      var pagesize: vm_size_t = 0
      let host_port: mach_port_t = mach_host_self()
      var host_size: mach_msg_type_number_t
        = mach_msg_type_number_t(MemoryLayout<vm_statistics_data_t>.stride / MemoryLayout<integer_t>.stride)
      host_page_size(host_port, &pagesize)
      
      var vm_stat: vm_statistics = vm_statistics_data_t()
      withUnsafeMutablePointer(to: &vm_stat) { (vmStatPointer) -> Void in
        vmStatPointer.withMemoryRebound(to: integer_t.self, capacity: Int(host_size)) {
          if (host_statistics(host_port, HOST_VM_INFO, $0, &host_size) != KERN_SUCCESS) {
            log("Error: Failed to fetch vm statistics")
          }
        }
      }
      
      /* Stats in bytes */
      let mem_used: Int64 = Int64(vm_stat.active_count +
        vm_stat.inactive_count +
        vm_stat.wire_count) * Int64(pagesize)
      
      //     let mem_free: Int64 = Int64(vm_stat.free_count) * Int64(pagesize)
      let totalMemory = Int64(ProcessInfo.processInfo.physicalMemory)
      return totalMemory - mem_used
    }
    
    // MARK:  appUsedRam
    func appUsedRam() -> UInt64? {
      // From Quinn the Eskimo at Apple.
      // https://forums.developer.apple.com/thread/105088#357415
      // The `TASK_VM_INFO_COUNT` and `TASK_VM_INFO_REV1_COUNT` macros are too
      // complex for the Swift C importer, so we have to define them ourselves.
      let TASK_VM_INFO_COUNT = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
      let TASK_VM_INFO_REV1_COUNT = mach_msg_type_number_t(MemoryLayout.offset(of: \task_vm_info_data_t.min_address)! / MemoryLayout<integer_t>.size)
      var info = task_vm_info_data_t()
      var count = TASK_VM_INFO_COUNT
      let kr = withUnsafeMutablePointer(to: &info) { infoPtr in
        infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
          task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
        }
      }
      guard
        kr == KERN_SUCCESS,
        count >= TASK_VM_INFO_REV1_COUNT
        else { return nil }
      return info.phys_footprint
    }
    
    // MARK:  freeStorage
    func freeStorage() -> Int64?{
      let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
      let fileURL = URL(fileURLWithPath: paths[0] as String)
      //Alternative: nsfilesystemsize, free size filesystemsize in bytes
      do {
        let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let capacity = values.volumeAvailableCapacityForImportantUsage {
          return capacity
        }
      } catch {
        log("Error: Failed to fetch storage from \(fileURL)")
      }
      return nil
    }
    
    // MARK:  storageUsedByApp
    func storageUsedByApp() -> UInt64 {
      var totalSize: UInt64 = 0
      // create list of directories
      
      // 1. main bundle
      var paths = [Bundle.main.bundlePath]
      
      // 2. temp Dir
      paths.append(NSTemporaryDirectory() as String)
      
      // 3. document Dirs
      let docDirs = NSSearchPathForDirectoriesInDomains(
        FileManager.SearchPathDirectory.documentDirectory,
        .userDomainMask, true)
      for dir in docDirs {
        paths.append(dir)
      }
      
      // 4. lib Dirs
      let libDirs = NSSearchPathForDirectoriesInDomains(
        FileManager.SearchPathDirectory.libraryDirectory,
        .userDomainMask, true)
      for dir in libDirs {
        paths.append(dir)
      }
      
      // combine sizes
      for path in paths {
        if let size = bytesIn(directory: path) {
          totalSize += size
        }
      }
      return totalSize
    }
    
    //calculate all sizes of given dir
    func bytesIn(directory: String) -> UInt64? {
      let fm = FileManager.default
      guard let subdirectories = try? fm.subpathsOfDirectory(atPath: directory) as NSArray else {
        log("Calculate size in dir \(directory) skipped")
        return nil
      }
      let enumerator = subdirectories.objectEnumerator()
      var size: UInt64 = 0
      while let fileName = enumerator.nextObject() as? String {
        do {
          let fileDictionary = try fm.attributesOfItem(atPath: directory.appending("/" + fileName)) as NSDictionary
          size += fileDictionary.fileSize()
        } catch let err {
          log("err getting attributes of file \(fileName): \(err.localizedDescription)")
        }
      }
      return size
    }
  }
}
