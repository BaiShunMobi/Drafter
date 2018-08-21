//
//  Mapper.swift
//  Mapper
//
//  Created by LZephyr on 2017/9/26.
//  Copyright © 2017年 LZephyr. All rights reserved.
//

import Foundation
//import PathKit

let OutputFolder = "DrafterStage"
let DataPlaceholder = "DrafterDataPlaceholder"
let DrafterVersion = "0.4.1"

class Drafter {
    
    // MARK: - Public
    
    var mode: DraftMode = .invokeGraph
    var outputType: DraftOutputType = .html
    var keywords: [String] = []
    var selfOnly: Bool = false // 只包含定义在用户代码中的方法节点
    var disableAutoOpen: Bool = false // 解析完成不要自动打开结果
    var disableCache: Bool = false // 不使用缓存
    
    /// 等待处理的所有源文件
    fileprivate var files: [Path] = []
    
    /// 待解析的文件或文件夹, 目前只支持.h、.m和.swift文件
    var paths: String = "" {
        didSet {
            // 多个文件用逗号分隔
            let pathValues = paths.split(by: ",")
            
            files = pathValues
                .map {
                    return Path($0)
                }
                .flatMap { (path) -> [Path] in
                    guard path.exists else {
                        return []
                    }
                    return path.files
                }
        }
    }
    
    /// 自己创建的源文件
    fileprivate var mineFiles: [Path] = []
    fileprivate var mineStatisticsList: [Int] = []      // 类数量，方法数量，参数数量
    fileprivate var mineCodeLines: Int = 0
    fileprivate var mineFileCount: Int = 0
    
    /// 部门内部的源文件
    fileprivate var departmentFiles: [Path] = []
    fileprivate var departmentStatisticsList: [Int] = []
    fileprivate var departmentCodeLines: Int = 0
    fileprivate var departmentFileCount: Int = 0
    
    /// github上的源文件
    fileprivate var githubFiles: [Path] = []
    fileprivate var githubStatisticsList: [Int] = []
    fileprivate var githubCodeLines: Int = 0
    fileprivate var githubFileCount: Int = 0
    
    /// 源文件的配置描述文件
    var configFilePath: String = "" {
        didSet {
            if let file: FileHandle = FileHandle(forReadingAtPath: configFilePath) {
                let data = file.readDataToEndOfFile()
                file.closeFile()
                
                do {
                    guard let jsonDic = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String:String] else {
                        return
                    }
                    
                    guard var basePath = jsonDic["basePath"] else {
                        return
                    }
                    if basePath.last != "/" {
                        basePath.append("/")
                    }
                    
                    if let mineFilePaths = jsonDic["mineFilePath"] {
                        mineFiles = resolveFilePath(basePath: basePath, relativePaths: mineFilePaths)
                        mineStatisticsList = analysis(files: mineFiles)
                        let rt = ProportionAnalysis.shared.sumCodeLinesAndFileCount(files: mineFiles)
                        mineFileCount = rt[0]
                        mineCodeLines = rt[1]
                    }
                    
                    if let departmentFilePaths = jsonDic["departmentFilePath"] {
                        departmentFiles = resolveFilePath(basePath: basePath, relativePaths: departmentFilePaths)
                        departmentStatisticsList = analysis(files: departmentFiles)
                        let rt = ProportionAnalysis.shared.sumCodeLinesAndFileCount(files: departmentFiles)
                        departmentFileCount = rt[0]
                        departmentCodeLines = rt[1]
                    }
                    
                    if let githubFilePaths = jsonDic["githubFilePath"] {
                        githubFiles = resolveFilePath(basePath: basePath, relativePaths: githubFilePaths)
                        githubStatisticsList = analysis(files: githubFiles)
                        let rt = ProportionAnalysis.shared.sumCodeLinesAndFileCount(files: githubFiles)
                        githubFileCount = rt[0]
                        githubCodeLines = rt[1]
                    }
                    
                    if mineStatisticsList.count == 3 && departmentStatisticsList.count == 3 && githubStatisticsList.count == 3 {
                        let allClassCount = mineStatisticsList[0] + departmentStatisticsList[0] + githubStatisticsList[0]
                        let allMethodCount = mineStatisticsList[1] + departmentStatisticsList[1] + githubStatisticsList[1]
                        let allParamCount = mineStatisticsList[2] + departmentStatisticsList[2] + githubStatisticsList[2]
                        let allFileCount = mineFileCount + departmentFileCount + githubFileCount
                        let allCodeLines = mineCodeLines + departmentCodeLines + githubCodeLines
                        
                        let mineClassProportion = 100 * Double(mineStatisticsList[0]) / Double(allClassCount)
                        let departmentClassProportion = 100 * Double(departmentStatisticsList[0]) / Double(allClassCount)
                        let githubClassProportion = 100 * Double(githubStatisticsList[0]) / Double(allClassCount)
                        
                        let mineMethodProportion = 100 * Double(mineStatisticsList[1]) / Double(allMethodCount)
                        let departmentMethodProportion = 100 * Double(departmentStatisticsList[1]) / Double(allMethodCount)
                        let githubMethodProportion = 100 * Double(githubStatisticsList[1]) / Double(allMethodCount)
                        
                        let mineParamsProportion = 100 * Double(mineStatisticsList[2]) / Double(allParamCount)
                        let departmentParamsProportion = 100 * Double(departmentStatisticsList[2]) / Double(allParamCount)
                        let githubParamsProportion = 100 * Double(githubStatisticsList[2]) / Double(allParamCount)
                        
                        let mineFilesProportion = 100 * Double(mineFileCount) / Double(allFileCount)
                        let departmentFilesProportion = 100 * Double(departmentFileCount) / Double(allFileCount)
                        let githubFilesProportion = 100 * Double(githubFileCount) / Double(allFileCount)
                        
                        let mineCodeLinesProportion = 100 * Double(mineCodeLines) / Double(allCodeLines)
                        let departmentCodeLinesProportion  = 100 * Double(departmentCodeLines) / Double(allCodeLines)
                        let githubCodeLinesProportion = 100 * Double(githubCodeLines) / Double(allCodeLines)
                        
                        print("全部类数量为:\(allClassCount)")
                        print("自己代码类占比为:\(String(format: "%.2f", mineClassProportion))%")
                        print("部门代码类占比为:\(String(format: "%.2f", departmentClassProportion))%")
                        print("开源代码类占比为:\(String(format: "%.2f", githubClassProportion))%")
                        
                        print("全部方法数量为:\(allMethodCount)")
                        print("自己代码方法占比为:\(String(format: "%.2f", mineMethodProportion))%")
                        print("部门代码方法占比为:\(String(format: "%.2f", departmentMethodProportion))%")
                        print("开源代码方法占比为:\(String(format: "%.2f", githubMethodProportion))%")
                        
                        print("全部参数数量为:\(allParamCount)")
                        print("自己代码参数占比为:\(String(format: "%.2f", mineParamsProportion))%")
                        print("部门代码参数占比为:\(String(format: "%.2f", departmentParamsProportion))%")
                        print("开源代码参数占比为:\(String(format: "%.2f", githubParamsProportion))%")
                        
                        print("全部文件数量为:\(allFileCount)")
                        print("自己代码文件数占比为:\(String(format: "%.2f", mineFilesProportion))%")
                        print("部门代码文件数占比为:\(String(format: "%.2f", departmentFilesProportion))%")
                        print("开源代码文件数占比为:\(String(format: "%.2f", githubFilesProportion))%")
                        
                        print("全部代码行数为:\(allCodeLines)")
                        print("自己代码行数占比为:\(String(format: "%.2f", mineCodeLinesProportion))%")
                        print("部门代码行数占比为:\(String(format: "%.2f", departmentCodeLinesProportion))%")
                        print("开源代码行数占比为:\(String(format: "%.2f", githubCodeLinesProportion))%")
                    }
                } catch {
                    print("Error: \(error)")
                }
            }
        }
    }
    /// 统计文件和代码行数
    func sumCodeLinesAndFileCount(files:[Path]) -> [Int] {
        let rt = ProportionAnalysis.shared.sumCodeLinesAndFileCount(files: files)
        return rt
    }
    
    /// 统计类，函数和参数的数目
    func analysis(files:[Path]) -> [Int] {
        let classNodes = ParserRunner.runner.parse(files: files, usingCache: !disableCache)
        
        // 格式化
        let jsonDic = classNodes.map { $0.toTemplateJSON() }
        
        // 统计各种数量
        let statisticList = ProportionAnalysis.shared.analysis(classArray: jsonDic)
        
        return statisticList;
    }
    
    /// 生成调用图
    func craft() {
        if outputType == .html {
            craftHTML()
        } else { // 输出为图片的话需要根据选项做进一步的处理
            switch mode {
            case .invokeGraph:
                craftinvokeGraph()
            case .inheritGraph:
                craftInheritGraph()
            case .both:
                craftInheritGraph()
                craftinvokeGraph()
            }
        }
    }
    
    // MARK: - Private
    
    private func resolveFilePath(basePath: String, relativePaths: String) -> [Path] {
        // 多个文件用逗号分隔
        let pathValues = relativePaths.split(by: ",")
        
        let sourcefiles = pathValues
            .map {
                var absolutePath = basePath
                absolutePath.append($0)
                return absolutePath
            }
            .map {
                return Path($0)
            }
            .flatMap { (path) -> [Path] in
                guard path.exists else {
                    return []
                }
                return path.files
            }
        return sourcefiles
    }
    
    /// 解析所有输入并生成一个HTML的输出
    func craftHTML() {
        let classNodes = ParserRunner.runner.parse(files: files, usingCache: !disableCache)
        
        // 格式化
        var jsonString: String? = nil
        let jsonDic = classNodes.map { $0.toTemplateJSON() }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: jsonDic, options: .prettyPrinted)
            jsonString = String(data: data, encoding: .utf8)
        } catch {
            print("Error: \(error)")
        }
        
        guard let json = jsonString else {
            print("Fail to generate json data!")
            return
        }
        
        print("\(json)")
        
        // 目标输出位置
        let targetFolder = "./\(OutputFolder)"
        let targetHtml = "\(targetFolder)/index.html"
        let targetJs = "\(targetFolder)/bundle.js"
        
        // 前端模板位置
        let templateHtml = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".drafter/index.html").path
        let templateJs = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".drafter/bundle.js").path
        
        guard FileManager.default.fileExists(atPath: templateHtml), FileManager.default.fileExists(atPath: templateJs) else {
            print("Error: Missing drafter template files. Try to reinstall Drafter")
            return
        }
        
        do {
            // 创建文件夹
            if FileManager.default.fileExists(atPath: targetFolder) {
                try FileManager.default.removeItem(atPath: targetFolder)
            }
            try FileManager.default.createDirectory(atPath: targetFolder, withIntermediateDirectories: true, attributes: nil)
            
            var htmlContent = try String(contentsOfFile: templateHtml)
            htmlContent = htmlContent.replacingOccurrences(of: DataPlaceholder, with: json)
            
            // 创建HTML文件
            if FileManager.default.fileExists(atPath: targetHtml) {
                try FileManager.default.removeItem(atPath: targetHtml)
            }
            FileManager.default.createFile(atPath: targetHtml, contents: htmlContent.data(using: .utf8), attributes: nil)
            
            try FileManager.default.copyItem(atPath: templateJs, toPath: targetJs)
        } catch {
            print("Error: Fail to copy resource!")
        }
        
        print("Parse result save to './DrafterStage/index.html'")
        
        // 自动打开网页
        if !disableAutoOpen {
            Executor.execute("open", targetHtml, help: "Auto open failed")
        }
    }
}

// MARK: - Deprecated

fileprivate extension Drafter {
    /// 生成类继承关系图
    fileprivate func craftInheritGraph() {
        var (classes, protocols) = ParserRunner.runner.parseInerit(files: files)
        
        // 过滤、生成结果
        classes = classes.filter({ $0.className.contains(keywords) })
        protocols = protocols.filter({ $0.name.contains(keywords) })
        
        let resultPath = DotGenerator.generate(classes: classes, protocols: protocols, filePath: "Inheritance")
        
        // Log result
        for node in classes {
            print(node)
        }
        
        if !disableAutoOpen {
            Executor.execute("open", resultPath, help: "Auto open failed")
        }
    }
    
    /// 生成方法调用关系图
    fileprivate func craftinvokeGraph() {
        // 1. 解析每个文件中的方法
        let results = ParserRunner.runner.parseMethods(files: files)
        
        // 2. 过滤、生成结果
        var outputFiles = [String]()
        for (file, nodes) in results {
            outputFiles.append(DotGenerator.generate(filted(nodes), filePath: file))
        }
        
        // 如果只有一张图片则自动打开
        if outputFiles.count == 1, !disableAutoOpen {
            Executor.execute("open", outputFiles[0], help: "Auto open failed")
        }
    }
}

// MARK: - 过滤方法

fileprivate extension Drafter {
    
    func filted(_ methods: [MethodNode]) -> [MethodNode] {
        var methods = methods
        methods = filtedSelfMethod(methods)
        methods = extractSubtree(methods)
        return methods
    }
    
    /// 仅保留自定义方法之间的调用
    func filtedSelfMethod(_ methods: [MethodNode]) -> [MethodNode] {
        if selfOnly {
            var selfMethods = Set<Int>()
            for method in methods {
                selfMethods.insert(method.hashValue)
            }
            
            return methods.map({ (method) -> MethodNode in
                var selfInvokes = [MethodInvokeNode]()
                for invoke in method.invokes {
                    if selfMethods.contains(invoke.hashValue) {
                        selfInvokes.append(invoke)
                    }
                }
                method.invokes = selfInvokes
                return method
            })
        }
        return methods
    }
    
    /// 根据关键字提取子树
    func extractSubtree(_ nodes: [MethodNode]) -> [MethodNode] {
        guard keywords.count != 0, nodes.count != 0 else {
            return nodes
        }
        
        // 过滤出包含keyword的根节点
        var subtrees: [MethodNode] = []
        let filted = nodes.filter {
            $0.description.contains(keywords)
        }
        subtrees.append(contentsOf: filted)
        
        // 递归获取节点下面的调用分支
        func selfInvokes(_ invokes: [MethodInvokeNode], _ subtrees: [MethodNode]) -> [MethodNode] {
            guard invokes.count != 0 else {
                return subtrees
            }
            
            let methods = nodes.filter({ (method) -> Bool in
                invokes.contains(where: { $0.hashValue == method.hashValue }) &&
                !subtrees.contains(where: { $0.hashValue == method.hashValue })
            })
            
            return selfInvokes(methods.reduce([], { $0 + $1.invokes}), methods + subtrees)
        }
        
        subtrees.append(contentsOf: selfInvokes(filted.reduce([], { $0 + $1.invokes}), subtrees))
        
        return subtrees
    }
}

// MARK: - 文件处理

fileprivate extension Drafter {
    
    func supported(_ file: String) -> Bool {
        if file.hasSuffix(".h") || file.hasSuffix(".m") || file.hasSuffix(".swift") {
            return true
        }
        return false
    }

}
