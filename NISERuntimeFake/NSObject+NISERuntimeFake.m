//
//  Copyright (c) 2013 Lukasz Wolanczyk. All rights reserved.
//

#import <objc/runtime.h>
#import "NSObject+NISERuntimeFake.h"

@implementation NSObject (NISERuntimeFake)

+ (Class)fakeClass {
    NSString *className = [NSString stringWithFormat:@"NISEFake-%@-%@", [[NSUUID UUID] UUIDString], NSStringFromClass([self class])];
    [self assertClassNotExists:NSClassFromString(className)];
    
    Class class = objc_allocateClassPair(self.class, [className cStringUsingEncoding:NSUTF8StringEncoding], 0);
    objc_registerClassPair(class);
    
    return class;
}

+ (id)fake {
    Class fakeClass = [self fakeClass];
    return [[fakeClass alloc] init];
}

+ (id)fakeObjectWithProtocol:(Protocol *)protocol includeOptionalMethods:(BOOL)optional {
    Class fakeClass = [self fakeClass];
    [self addProtocolWithConformingProtocols:protocol toClass:fakeClass includeOptionalMethods:optional];
    return [[fakeClass alloc] init];
}

- (void)overrideInstanceMethod:(SEL)selector withImplementation:(id)block {
    Method method = class_getInstanceMethod([self class], selector);
    [self assertClassIsFake:method];
    [self assertMethodExists:method];
    if (method) {
        IMP implementation = imp_implementationWithBlock(block);
        class_replaceMethod([self class], selector, implementation, method_getTypeEncoding(method));
    }
}

#pragma mark - Helpers

+ (void)addProtocolWithConformingProtocols:(Protocol *)baseProtocol toClass:(Class)class includeOptionalMethods:(BOOL)optional {
    [self addMethodsFromProtocol:baseProtocol toClass:class includeOptionalMethods:optional];

    unsigned int protocolCount;
    __unsafe_unretained Protocol **protocols = protocol_copyProtocolList(baseProtocol, &protocolCount);

    for (int i = 0; i < protocolCount; i++) {
        Protocol *protocol = protocols[i];
        [self addProtocolWithConformingProtocols:protocol toClass:class includeOptionalMethods:optional];
    }
}

+ (void)addMethodsFromProtocol:(Protocol *)protocol toClass:(Class)class includeOptionalMethods:(BOOL)optional {
    if (protocol == @protocol(NSObject)) {
        return;
    }

    class_addProtocol(class, protocol);
    void (^enumerate)(BOOL) = ^(BOOL isRequired) {
        unsigned int descriptionCount;
        struct objc_method_description *methodDescriptions = protocol_copyMethodDescriptionList(protocol, isRequired, YES, &descriptionCount);
        for (int i = 0; i < descriptionCount; i++) {
            struct objc_method_description methodDescription = methodDescriptions[i];
            IMP implementation = imp_implementationWithBlock(^id {
                return nil;
            });
            class_addMethod(class, methodDescription.name, implementation, methodDescription.types);
        }
    };
    enumerate(YES);
    if (optional) {
        enumerate(NO);
    }
}

#pragma mark - Assertions

- (void)assertClassNotExists:(Class)aClass {
    NSString *description = [NSString stringWithFormat:@"Could not create %@ class, because class with such name already exists",
                                                       NSStringFromClass(aClass)];
    NSAssert(!aClass, description);
}

- (void)assertClassIsFake:(Method)method {
    Class aClass = [self class];
    NSString *description = [NSString stringWithFormat:@"Could not override method %@, because %@ is not a fake class",
                                                       NSStringFromSelector(method_getName(method)),
                                                       NSStringFromClass(aClass)];
    NSAssert([NSStringFromClass(aClass) hasPrefix:@"NISEFake"], description);
}

- (void)assertMethodExists:(Method)method {
    NSString *description = [NSString stringWithFormat:@"Could not override method %@, because such method does not exist in %@ class",
                                                       NSStringFromSelector(method_getName(method)),
                                                       NSStringFromClass([self class])];
    NSAssert(method, description);
}

@end
