/*
     File:       TreeNode.m
 
     Contains:   Generic Tree node and data structures (TreeNode, and TreeNodeData).
 
                 TreeNode is a node in a doubly linked tree data structure. 
                 TreeNode's have weak references to their parent (to avoid retain
                 cycles since parents retain their children).  Each node has 0 or
                 more children and a reference to a piece of TreeNodeData data.  
                 The TreeNode provides method to manipulate and extract structural
                 information about a tree.  For instance, TreeNode implements:
                 insertChild:atIndex:, removeChild:, isDescendantOfNode:, and other
                 useful operations on tree nodes. TreeNode and TreeNodeData provide
                 the structure and KWCommonMethods functionality of trees, and are expected
                 to be subclassed.
                 
     Version:    Technology: Mac OS X
                 Release:    Mac OS X
 
     Copyright:  (c) 2002 by Apple Computer, Inc., all rights reserved
 
     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:
 
                     http://developer.apple.com/bugreporter/
*/

/*
 IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc. ("Apple") in
 consideration of your agreement to the following terms, and your use, installation, 
 modification or redistribution of this Apple software constitutes acceptance of these 
 terms.  If you do not agree with these terms, please do not use, install, modify or 
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and subject to these 
 terms, Apple grants you a personal, non-exclusive license, under Apple’s copyrights in 
 this original Apple software (the "Apple Software"), to use, reproduce, modify and 
 redistribute the Apple Software, with or without modifications, in source and/or binary 
 forms; provided that if you redistribute the Apple Software in its entirety and without 
 modifications, you must retain this notice and the following text and disclaimers in all 
 such redistributions of the Apple Software.  Neither the name, trademarks, service marks 
 or logos of Apple Computer, Inc. may be used to endorse or promote products derived from 
 the Apple Software without specific prior written permission from Apple. Except as expressly
 stated in this notice, no other rights or licenses, express or implied, are granted by Apple
 herein, including but not limited to any patent rights that may be infringed by your 
 derivative works or by other works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO WARRANTIES, 
 EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, 
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS 
 USE AND OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR CONSEQUENTIAL 
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS 
 OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, 
 REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND 
 WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR 
 OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "TreeNode.h"
#import "NSArray_Extensions.h"

@implementation TreeNodeData 

- (NSComparisonResult) compare:(TreeNodeData *)other
{
    // Return anything, it is expected this will be overridden by subclasses.
    // For instance, FSTreeData compares names!
    return NSOrderedAscending;
}

- (void)setName:(NSString*)name
{
}

- (NSString*) name
{
	return @"Huh?";
}

- (NSString*) kind
{
	return @"Wha?";
}

- (BOOL) isExpandable
{
	return NO;
}

- (NSImage*) icon
{
	return nil;
}

@end

@implementation TreeNode

+ (id) treeNodeWithData:(TreeNodeData*)data
{
    return [[[self alloc] initWithData: data  parent:nil] autorelease]; 
}

- (id) initWithData:(TreeNodeData*)data parent:(TreeNode*)parent
{
    if (self = [super init])
	{
		nodeData = [data retain];
		nodeChildren = [[NSMutableArray array] retain];
		nodeParent = parent;
    }
	
    return self;
}

- (void)dealloc
{
    [nodeData release];
	nodeData = nil;
	
	[nodeChildren release];
    nodeChildren = nil;
    [super dealloc];
}

// ================================================================
// Methods used to manage a node and its children.
// ================================================================

- (void)setNodeData:(TreeNodeData*)data
{ 
	if (nodeData != data)
	{
		[nodeData release]; 
		nodeData = [data retain]; 
	}
}

- (TreeNodeData*) nodeData
{ 
    return [[nodeData retain] autorelease];; 
}

- (void)setNodeParent:(TreeNode*)parent
{
	nodeParent = parent;
}

- (TreeNode*) nodeParent
{ 
    return nodeParent; 
}

- (void)addChild:(TreeNode*)child
{
	switch (sortOrder)
	{
		case TNSortOrderReverse:
			[nodeChildren insertObject:child sortedBySelector:@selector(reverseCompare:)];
			break;
		
		case TNSortOrderNormal:
		default:
			[nodeChildren insertObject:child sortedBySelector:@selector(compare:)];
			break;
	}

[child setNodeParent:self];
}

- (void)addChildren:(NSArray*)children
{
	[children makeObjectsPerformSelector:@selector(addChild:) withObject:self];
}

- (void)removeChild:(TreeNode*)child
{
    int index = [self indexOfChild: child];
    if (index != NSNotFound)
	{
		[nodeChildren removeObjectAtIndex:index];
    }
}

- (void)removeFromParent
{
    [[self nodeParent] removeChild:self];
}

- (int) indexOfChild:(TreeNode*)child
{
    return [nodeChildren indexOfObject:child];
}

- (int) indexOfChildIdenticalTo:(TreeNode*)child
{
    return [nodeChildren indexOfObjectIdenticalTo:child];
}

- (int) numberOfChildren
{
    return [[self children] count];
}

- (NSArray*) children
{
    return [NSArray arrayWithArray: nodeChildren];
}

- (TreeNode*) firstChild
{
    return [[self children] objectAtIndex:0];
}

- (TreeNode*) lastChild
{
    return [[self children] lastObject];
}

- (TreeNode*) childAtIndex:(int)index
{
    return [[self children] objectAtIndex:index];
}

- (BOOL) isDescendantOfNode:(TreeNode*)node
{
    // returns YES if 'node' is an ancestor.
    // Walk up the tree, to see if any of our ancestors is 'node'.
    TreeNode *parent = self;
    while (parent)
	{
        if(parent == node)
			return YES;
        parent = [parent nodeParent];
    }
    return NO;
}

- (BOOL) isDescendantOfNodeInArray:(NSArray*)nodes
{
    // returns YES if any 'node' in the array 'nodes' is an ancestor of ours.
    // For each node in nodes, if node is an ancestor return YES.  If none is an
    // ancestor, return NO.
    NSEnumerator *nodeEnum = [nodes objectEnumerator];
    TreeNode *node = nil;
    while ((node = [nodeEnum nextObject]) != nil)
	{
        if ([self isDescendantOfNode:node]) return YES;
    }
    return NO;
}

- (void)setSortOrder:(TNSortOrder)order
{
	sortOrder = order;
}

- (TNSortOrder) sortOrder
{
	return sortOrder;
}

- (void)recursiveSortChildren
{
	switch (sortOrder)
	{
		case TNSortOrderReverse:
			[nodeChildren sortUsingSelector:@selector(reverseCompare:)];
			break;
		
		case TNSortOrderNormal:
		default:
			[nodeChildren sortUsingSelector:@selector(compare:)];
			break;
	}
    [nodeChildren makeObjectsPerformSelector: @selector(recursiveSortChildren)];
}

- (NSString*) description
{
    // Return something that will be useful for debugging.
    return [NSString stringWithFormat: @"{%@}", nodeData];
}

// Returns the minimum nodes from 'allNodes' required to cover the nodes in 'allNodes'.
// This methods returns an array containing nodes from 'allNodes' such that no node in
// the returned array has an ancestor in the returned array.

// There are better ways to compute this, but this implementation should be efficient for our app.
+ (NSArray *) minimumNodeCoverFromNodesInArray: (NSArray *)allNodes
{
    NSMutableArray*	minimumCover = [NSMutableArray array];
    NSMutableArray*	nodeQueue = [NSMutableArray arrayWithArray:allNodes];
    TreeNode*		node = nil;
	
    while ([nodeQueue count])
	{
        node = [nodeQueue objectAtIndex:0];
        [nodeQueue removeObjectAtIndex:0];
        while ([node nodeParent] && [nodeQueue containsObjectIdenticalTo:[node nodeParent]])
		{
            [nodeQueue removeObjectIdenticalTo: node];
            node = [node nodeParent];
        }
        if ([node isDescendantOfNodeInArray: minimumCover] == NO)
			[minimumCover addObject: node];
			
        [nodeQueue removeObjectIdenticalTo: node];
    }
    return minimumCover;
}

- (NSComparisonResult) compare:(TreeNode*)node
{
    // Compare nodes to each other by comparing the data part.
    return [nodeData compare:[node nodeData]];
}

- (NSComparisonResult) reverseCompare:(TreeNode*)node 
{
    // Compare nodes to each other by comparing the data part.
    return [[node nodeData] compare:nodeData];
}

@end
