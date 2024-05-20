import Foundation
import UIKit

class Task {
    weak var owner: AnyObject?
    let onCompletion: (UIImage?, Error?, FetchOperation) -> Void

    init(_ owner: AnyObject?, onCompletion: @escaping (UIImage?, Error?, FetchOperation) -> Void) {
        self.owner = owner
        self.onCompletion = onCompletion
    }
}

class Operative {
    var tasks = [Task]()
    var receiveData = Data()

    func remove(_ task: Task) {
        guard let index = tasks.firstIndex(of: task) else {
            return
        }
        tasks.remove(at: index)
    }

    func update(_ task: Task) {
        guard let index = tasks.firstIndex(of: task) else {
            tasks.append(task)
            return
        }
        tasks[index] = task
    }
}


extension Task: Equatable {}
    func ==(lhs: Task, rhs: Task) -> Bool {
        guard let leftTaskOwner = lhs.owner, let rightTaskOwner = rhs.owner else {
            return false
        }
        return leftTaskOwner.isEqual(rightTaskOwner)
}
