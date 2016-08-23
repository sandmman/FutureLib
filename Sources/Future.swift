import Foundation
import Dispatch

public enum Errors: Error {
    case timeout
}

class Future<T> {
    
    // var dispatchQueue: DispatchQueue?
    // var onCompletion: (@escaping (T)->Any)?
    // var onFailureCallback: (@escaping (Error)->Void)?
    
    var value: Result<T>?
    
    let lock = DispatchSemaphore(value: 0)

    var timer: DispatchSourceTimer? = nil

    public init() {
        
    }

    public func withTimeout(of time: Int) -> Future<T> {
        let timeout = DispatchQueue(label: "future", qos: DispatchQoS.background, attributes: .concurrent)
        
        timer = timer ?? DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags.strict, queue: timeout)

        timer?.scheduleOneshot(deadline: .now() + .seconds(time) )
        
        timer?.setEventHandler {
            print("executed")
            self.notify(.error(Errors.timeout))
        }
        
        timer?.resume()

        return self
    }

    public func notify(_ value: Result<T>) {
        
        //lock.wait()
        self.value = value
        lock.signal()
    }
    
    /**
     Set up a routine for when the Future has a successful value.
     
     - parameter qos:                Quality service level of the returned completionHandler
     - parameter completionHandler:  Callback with a successful value
     
     - returns: new Future
     */
    @discardableResult
    public func onSuccess<S>(qos: DispatchQoS,
                          completionHander: @escaping (T)->S) -> Future<S> {
        
        // onCompletion = completionHander
        let dispatchQueue = DispatchQueue(label: "future", qos: qos, attributes: .concurrent)
        
        let nextFuture = Future<S>()
        
        dispatchQueue.async {
            
            self.lock.wait()
            
            if let val = self.value {

                self.killTimer()
                
                switch val {
                case .success(let a):
                    
                    let returnedValue = completionHander(a)
                    nextFuture.notify(.success(returnedValue))
                    
                case .error(let error):
                    
                    //self.onFailure?(error)
                    nextFuture.notify(.error(error))
                    
                }
            }
        }
        
        return nextFuture
    }
    
    /**
     Set up a routine if there is an error.
     
     - parameter completionHandler:  Callback with an error
     
     - returns: new Future
     */
    @discardableResult
    public func onFailure(completionHander: @escaping (Error)->Void) -> Future<T> {
        
        self.lock.wait()

        if let val = self.value {

            self.killTimer()

            switch val {
            case .success(let vals):
                print("This should not happen \(vals)")
            case .error(let error):
                completionHander(error)
            }
        }
        
        return self
    }
    
    @discardableResult
    public func then(completionHandler: @escaping (T)->Void) -> Future<T> {
        // TODO: Unimplemented
        return Future()
    }
    
}

extension Future {

    func killTimer() {
        timer?.cancel()
        timer = nil
    }
}
    
