//
// Copyright (c) 2012, Quantcast Corp.
// This software is licensed under the Quantcast Mobile API Beta Evaluation Agreement and may not be used except as permitted thereunder or copied, modified, or distributed in any case.
//

#ifndef __has_feature
#define __has_feature(x) 0
#endif
#ifndef __has_extension
#define __has_extension __has_feature // Compatibility with pre-3.0 compilers.
#endif

#if __has_feature(objc_arc) && __clang_major__ >= 3
#error "Quantcast Measurement is not designed to be used with ARC. Please add '-fno-objc-arc' to this file's compiler flags"
#endif // __has_feature(objc_arc)

#import "QuantcastDatabase.h"

@implementation QuantcastDatabase

+(QuantcastDatabase*)databaseWithFilePath:(NSString*)inFilePath {
    
    return [[[QuantcastDatabase alloc] initWithFilePath:inFilePath] autorelease];
}


-(id)initWithFilePath:(NSString*)inFilePath {
    self = [super init];
    
    if ( self ) {
        _databaseFilePath = [inFilePath retain];
        
  
        self.enableLogging = NO;
    }
    
    return self;
}

-(void)dealloc {
    [_databaseFilePath release];
    
    [self closeDatabaseConnection];
    
    [super dealloc];
}

-(NSString*)databaseFilePath {
    return _databaseFilePath;
}

-(sqlite3*)databaseConnection {
    
    @synchronized( self ) {
        if (NULL == _databaseConnection) {
            const char* dbpath = [self.databaseFilePath UTF8String];
            
            if (sqlite3_open(dbpath, &_databaseConnection) != SQLITE_OK) {
                if ( self.enableLogging ) {
                    NSLog(@"QC Measurement: Could not open sqllite3 database with path = %@", self.databaseFilePath );
                }
                
                return NULL;
            }
        }
    }
    
    return _databaseConnection;
}
-(void)closeDatabaseConnection {
    @synchronized( self ) {
        if ( NULL != _databaseConnection ) {
            sqlite3_close(_databaseConnection);
            
            _databaseConnection = NULL;
        }
    }
}


-(BOOL)beginDatabaseTransaction {
    return [self executeSQL:@"BEGIN TRANSACTION;"];
}

-(BOOL)rollbackDatabaseTransaction {
    return [self executeSQL:@"ROLLBACK;"];
}


-(BOOL)endDatabaseTransaction {
    return [self executeSQL:@"COMMIT;"];
}

-(BOOL)executeSQL:(NSString*)inSQL {    
    @synchronized( self ) {
        if ( NULL != self.databaseConnection ) {
            sqlite3_stmt    *statement;
            
            const char *sql_stmt = [inSQL UTF8String];
            
            if ( sqlite3_prepare_v2(self.databaseConnection, sql_stmt, -1, &statement, NULL) != SQLITE_OK ) {
                if ( self.enableLogging ) {
                    NSLog(@"QC Measurement: Could not prepare sqllite3 statment with sql = %@", inSQL );
                }
                
                return NO;
            }
            
            if (sqlite3_step(statement) != SQLITE_DONE) {
                if ( self.enableLogging ) {
                    NSLog(@"QC Measurement: Could not step sqllite3 statment with sql = %@", inSQL );
                }
                
                return NO;
            }
            
            sqlite3_finalize(statement);
        }
    }
    
    return YES;
}

-(BOOL)executeSQL:(NSString*)inSQL withResultsColumCount:(NSUInteger)inResultsColumnCount producingResults:(NSArray**)outResultsArray {
    
    NSMutableArray* resultRows = nil;
    
    @synchronized(self){
        if ( NULL != self.databaseConnection ) {
            
            sqlite3_stmt    *statement;
            
            const char *sql_stmt = [inSQL UTF8String];
            
            if ( sqlite3_prepare_v2(self.databaseConnection, sql_stmt, -1, &statement, NULL) == SQLITE_OK ) {
                
                resultRows = [NSMutableArray arrayWithCapacity:1];
                
                while (sqlite3_step(statement) == SQLITE_ROW ) {
                    
                    NSMutableArray* rowValues = [NSMutableArray arrayWithCapacity:inResultsColumnCount];
                    
                    for (NSUInteger i = 0; i < inResultsColumnCount; ++i ) {
                        NSString* columnValue = [[[NSString alloc] initWithUTF8String:(const char *) sqlite3_column_text(statement, i)] autorelease];
                        
                        [rowValues addObject:columnValue];
                    }
                    
                    [resultRows addObject:rowValues];
                }
                
                sqlite3_finalize(statement);
            }
            else {
                if ( self.enableLogging ) {
                    NSLog(@"QC Measurement: Could not prepare sqllite3 statment with sql = %@", inSQL );
                }
                
                return NO;
            }
        }
    }
    
    (*outResultsArray) = resultRows;
    
    return YES;
}

-(int64_t)getLastInsertRowId {
    
    return sqlite3_last_insert_rowid( self.databaseConnection );
}

-(BOOL)setAutoIncrementTo:(int64_t)inAutoIncrementValue forTable:(NSString*)inTableName {
    NSString* sql = [NSString stringWithFormat:@"UPDATE sqlite_sequence SET seq = %qi WHERE name = '%@';",inAutoIncrementValue,inTableName];
    
    return [self executeSQL:sql];
}

-(int64_t)rowCountForTable:(NSString*)inTableName {
    
    NSString* sql = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@;",inTableName];
    
    NSArray* results = nil;
    
    if ([self executeSQL:sql withResultsColumCount:1 producingResults:&results]) {
        if ( 1 == [results count] ) {
            NSArray* rowResults = [results objectAtIndex:0];
            
            if ( 1 == [rowResults count] ) {
                NSNumber* countValue = [rowResults objectAtIndex:0];
                
                return [countValue longLongValue];
            }
        }
        
    }
    
    return 0;
}


#pragma mark - Debugging
@synthesize enableLogging;

- (NSString *)description {
    return [NSString stringWithFormat:@"<QuantcastDatabase %p: path = %@>", self, _databaseFilePath ];
}


@end
