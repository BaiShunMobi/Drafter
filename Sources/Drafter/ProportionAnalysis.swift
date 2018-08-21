//
//  ProportionAnalysis.swift
//  Drafter
//
//  Created by tongleiming on 2018/8/8.
//

import Foundation

fileprivate let maxConcurrent: Int = 4 // 多线程解析最大并发数

class ProportionAnalysis {
    
    static let shared = ProportionAnalysis()
    
    func analysis(classArray: [Any]) -> [Int] {
        // 1. 统计类数量
        let classCount = classArray.count
        
        var methodCount = 0
        var paramCount = 0
        for item in classArray {
            guard let classDic = item as? [String : Any] else {
                print("Error: 解析字典出错!");
                return []
            }
            guard let methodsDic = classDic["methods"] as? [String : Any] else {
                print("Error: 解析字典出错!");
                return []
            }
            // 2. 统计方法数量
            methodCount += methodsDic.count
            
            for (_, methodItem) in methodsDic {
                guard let methodItemDic = methodItem as? [String : Any] else {
                    print("Error: 解析字典出错!");
                    return []
                }
                guard let paramsArray = methodItemDic["params"] as? [Any] else {
                    print("Error: 解析字典出错!");
                    return []
                }
                // 3. 统计参数个数
                paramCount += paramsArray.count
            }
        }
        
        print("\(classCount), \(methodCount), \(paramCount)")
        return [classCount, methodCount, paramCount]
    }
    
    func sumCodeLinesAndFileCount(files:[Path]) -> [Int] {
        let ocFiles = files.filter { $0.isObjc }
        let swiftFiles = files.filter { $0.isSwift }
        
        let fileCount = ocFiles.count + swiftFiles.count
        var codeLines = 0
        
        // 1. 解析OC文件
        for file in ocFiles {
            semaphore.wait()
            DispatchQueue.global().async {
                var content: String
                do {
                    content = try file.read()
                    let a = content.split(by: "\n")
                    objc_sync_enter(self)
                    codeLines += a.count
                    objc_sync_exit(self)
                } catch {
                    print("Fail To Read File: \(error)")
                }
                print("统计完成: \(file.lastComponent)")
                self.semaphore.signal()
            }
        }
        
        // 2. 解析Swift文件
        for file in swiftFiles {
            semaphore.wait()
            DispatchQueue.global().async {
                var content: String
                do {
                    content = try file.read()
                    let a = content.split(by: "\n")
                    objc_sync_enter(self)
                    codeLines += a.count
                    objc_sync_exit(self)
                } catch {
                    print("Fail To Read File: \(error)")
                }
                print("统计完成: \(file.lastComponent)")
                self.semaphore.signal()
            }
        }
        
        waitUntilFinished()
        
        return [fileCount, codeLines]
    }
    
    /// 等待直到所有任务完成
    private func waitUntilFinished() {
        for _ in 0..<maxConcurrent {
            semaphore.wait()
        }
        for _ in 0..<maxConcurrent {
            semaphore.signal()
        }
    }
    
    fileprivate let semaphore = DispatchSemaphore(value: maxConcurrent)
}
