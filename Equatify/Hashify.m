//
//  Hashify.m
//  Equatify
//
//  Created by Даниил Храповицкий on 27.05.2021.
//

#import "Hashify.h"

@interface Hashify ()

@property XCSourceTextBuffer *buffer;

- (NSArray<NSString *> *)createNewLines;
- (NSString *)getType;
- (NSArray<NSString *> *)createBody;
- (NSArray<NSString *> *)getVariables;
- (NSArray<NSString *> *)createContentWithType:(NSString *)type andBody:(NSArray<NSString *> *)body;
- (BOOL)isCorrectString:(NSString *)string;

@end

@implementation Hashify

- (instancetype)initWithBuffer:(XCSourceTextBuffer *)buffer {
    self = [super init];
    
    if (self) {
        _buffer = buffer;
    }
    
    return self;
}

- (void)hashify {
    NSArray<NSString *> *newLines = [self createNewLines];
    
    NSLog(@"%@", newLines);
    
    [[[self buffer] lines] addObjectsFromArray:newLines];
}

- (NSArray<NSString *> *)createNewLines {
    NSString *type = [self getType];
    NSArray<NSString *> *body = [self createBody];
    
    return [self createContentWithType:type andBody:body];
}

- (NSString *)getType {
    if ([[[self buffer] selections] firstObject] == nil) {
        @throw [NSException exceptionWithName:@"No selection!" reason:@"There is no selected area!" userInfo:nil];
    }
    
    XCSourceTextRange *selection = [[[self buffer] selections] firstObject];
    NSInteger line = [selection start].line;
    NSString *firstLine = [[[self buffer] lines] castAtIndexToNSString](line);
    
    return [NSScanner scanTypeNameInString:firstLine];
}

- (NSArray<NSString *> *)createBody {
    NSArray<NSString *> *variables = [self getVariables];
    NSString *doubleIndentation = [@"" stringByPaddingToLength:2 * [[self buffer] indentationWidth] withString:@" " startingAtIndex:0];
    
    if ([variables count] == 0) {
        return [NSArray array];
    }
    
    return [variables map:^id _Nonnull(id  _Nonnull obj) {
        return [doubleIndentation stringByAppendingString:[NSString stringWithFormat:@"hasher.combine(%@)", obj]];
    }];
}

- (NSArray<NSString *> *)getVariables {
    if ([[[self buffer] selections] firstObject] == nil) {
        @throw [NSException exceptionWithName:@"No selection!" reason:@"There is no selected area!" userInfo:nil];
    }
    
    XCSourceTextRange *selection = [[[self buffer] selections] firstObject];
    NSInteger startLineIndex = [selection start].line + 1;
    NSInteger endLineIndex = [selection end].line;
    
    
    NSMutableArray *selectionRange = [NSMutableArray array];
    for (NSInteger i = startLineIndex; i < endLineIndex; i++) {
        [selectionRange addObject:@(i)];
    }
    
    return [[[selectionRange map:^id _Nonnull(id  _Nonnull obj) {
        return [[[self buffer] lines] castAtIndexToNSString]([obj integerValue]);
    }] filter:^BOOL(id  _Nonnull obj) {
        return [self isCorrectString:obj];
    }] flatMap:^id _Nonnull(id  _Nonnull obj) {
        return [NSScanner scanVariablesInString:obj];
    }];
}

- (NSArray<NSString *> *)createContentWithType:(NSString *)type andBody:(NSArray<NSString *> *)body {
    NSString *indentation = [@"" stringByPaddingToLength:[[self buffer] indentationWidth] withString:@" " startingAtIndex:0];
    NSString *extensionStart = [NSString stringWithFormat:@"extension %@: Hashable {", type];
    NSString *funcStart = [indentation stringByAppendingString:@"func hash(into hasher: inout Hasher) {"];
    NSString *funcEnd = [indentation stringByAppendingString:@"}"];
    NSString *extensionEnd = @"}";
    
    NSMutableArray<NSString *> *extension = [NSMutableArray arrayWithObjects:@"", extensionStart, funcStart, funcEnd, extensionEnd, nil];
    
    [body enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [extension insertObject:obj atIndex:idx + 3];
    }];
    
    return extension;
}

- (BOOL)isCorrectString:(NSString *)string {
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@" *\n" options:0 error:nil];
    NSRange range = NSMakeRange(0, string.length);
    NSString *replaced = [expression stringByReplacingMatchesInString:string options:0 range:range withTemplate:@""];
    
    NSScanner *scanner = [NSScanner scannerWithString:string];
    NSString *stringWithoutComments = [scanner scanUpToString:@"//"];
    [stringWithoutComments stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];
    
    return replaced.length != 0 && [stringWithoutComments isNotEqualTo:NULL] && ![stringWithoutComments containsString:@"func "] && ![stringWithoutComments containsString:@"{"] && ![stringWithoutComments containsString:@"}"] && ![stringWithoutComments containsString:@"print"] && ([stringWithoutComments containsString:@"var "] || [stringWithoutComments containsString:@"let "]);
}

@end
