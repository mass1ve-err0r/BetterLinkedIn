/**
 * BetterLinkedIn
 * An iOS tweak to remove ads across the LinkedIn app
 *
 * (c) Saadat Baig, me@sadat.dev
**/

#import <UIKit/UIKit.h>
#import <substrate.h>
#import <objc/runtime.h>

// Custom cells within LinkedIn
@interface NOXCollectionViewCell : UICollectionViewCell
@end

// May the lord forgive me for this sin as I have gotten rusty
static void (*orig_layoutSubviews)(id, SEL);
static void (*orig_upsellDidMoveToSuperview)(id, SEL);

// This is our entrypoint.
//
// The SDUI.* elements from LinkedIn reflect server-driven ui elements, classified by "proto.sdui.*" as seen in FLEX.
// We can abuse the fact they all contain debug information and a unique identifier, we simply scout for these bois 
static BOOL isSponsoredSemanticId(NSString *semanticId) {

    // I may be retarded so safeguard it
    if (!semanticId) return NO;

    return [semanticId containsString:@"sponsoredContentV2"]
        || [semanticId containsString:@"sponsoredCreative"]
        || [semanticId containsString:@"sponsoredUpdate"];
}

// We need to be kind to cell-reuse.
static void resetSponsoredOverlay(UIView *root) {
    UIView *label = [root viewWithTag:0xBEEF];
    if (label) [label removeFromSuperview];

    for (UIView *sub in root.subviews) {
        sub.hidden = NO;
    }
}

// labels (no, not the music kind...)
static UILabel *makeCenteredLabel(UIView *container, NSString *text) {
    UILabel *label = [[UILabel alloc] init];
    label.tag = 0xBEEF;
    label.text = text;
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = [UIColor secondaryLabelColor];
    label.font = [UIFont systemFontOfSize:13];
    label.numberOfLines = 0;
    label.lineBreakMode = NSLineBreakByWordWrapping;

    CGFloat maxWidth = container.bounds.size.width - 16; // 8pt padding each side
    CGSize fitSize = [label sizeThatFits:CGSizeMake(maxWidth, CGFLOAT_MAX)];

    label.frame = CGRectMake(
        (container.bounds.size.width - fitSize.width) / 2.0,
        (container.bounds.size.height - fitSize.height) / 2.0,
        fitSize.width,
        fitSize.height
    );
    label.autoresizingMask = UIViewAutoresizingFlexibleTopMargin
                            | UIViewAutoresizingFlexibleBottomMargin
                            | UIViewAutoresizingFlexibleLeftMargin
                            | UIViewAutoresizingFlexibleRightMargin;

    return label;
}

// Feed ad cells, rechecked on every layout pass since SDUI rebinds (tabun...)
static void hooked_layoutSubviews(id self, SEL _cmd) {
    orig_layoutSubviews(self, _cmd);

    @try {
        id debugInfo = [self valueForKey:@"sduiViewDebugInfo"];
        NSString *semanticId = debugInfo ? [debugInfo valueForKey:@"semanticId"] : nil;
        UIView *view = (UIView *)self;

        if (isSponsoredSemanticId(semanticId)) {
            if ([view viewWithTag:0xBEEF]) return;

            for (UIView *sub in view.subviews) {
                sub.hidden = YES;
            }

            UILabel *label = makeCenteredLabel(view, @"Ads removed by BetterLinkedIn ❤️\nLife's more than just work");
            [view addSubview:label];
        } else {
            resetSponsoredOverlay(view);
        }
    } @catch (NSException *e) {
        // Only the heavens know what went wrong, let us know
        NSLog(@"[BetterLinkedIn] layoutSubviews hook failed: %@", e);
    }
}

// Nav premium upsell bullshit
static void hooked_upsellDidMoveToSuperview(id self, SEL _cmd) {
    orig_upsellDidMoveToSuperview(self, _cmd);

    UIView *view = (UIView *)self;

    if ([view viewWithTag:0xBEEF]) return;

    for (UIView *sub in view.subviews) {
        sub.hidden = YES;
    }
    
    UILabel *label = makeCenteredLabel(view, @"BetterLinkedIn v1.0.0\n•\nhttps://github.com/mass1ve-err0r/BetterLinkedIn");
    [view addSubview:label];
}

%hook NOXCollectionViewCell
- (void)prepareForReuse {
    %orig;

    void (^recurse)(UIView *) = nil;
    __block void (^weakRecurse)(UIView *);
    recurse = ^(UIView *view) {
        resetSponsoredOverlay(view);
        for (UIView *sub in view.subviews) {
            weakRecurse(sub);
        }
    };
    weakRecurse = recurse;
    recurse(self.contentView);
}
%end

%ctor {
    // This is for the UICollectionView
    Class flexboxRoot = NSClassFromString(@"SDUI.FlexboxRootView");
    if (flexboxRoot && class_getInstanceMethod(flexboxRoot, @selector(layoutSubviews))) {
        MSHookMessageEx(flexboxRoot, @selector(layoutSubviews),
                        (IMP)hooked_layoutSubviews,
                        (IMP *)&orig_layoutSubviews);
    } else {
        NSLog(@"[BetterLinkedIn] FlexboxRootView layoutSubviews not found");
    }

    // And this one for the nav
    Class upsellView = NSClassFromString(@"Premium.PremiumNavPanelUpsellView");
    if (upsellView && class_getInstanceMethod(upsellView, @selector(didMoveToSuperview))) {
        MSHookMessageEx(upsellView, @selector(didMoveToSuperview),
                        (IMP)hooked_upsellDidMoveToSuperview,
                        (IMP *)&orig_upsellDidMoveToSuperview);
    } else {
        NSLog(@"[BetterLinkedIn] PremiumNavPanelUpsellView not found");
    }
}
