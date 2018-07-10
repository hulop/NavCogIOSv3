/*******************************************************************************
 * Copyright (c) 2014, 2015  IBM Corporation, Carnegie Mellon University and others
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *******************************************************************************/

#import "HLPSettingViewCell.h"

@implementation HLPSettingViewCell

// TODO
// customize accessibility

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
    [self addGestureRecognizer:recognizer];

    return self;
}

- (void) changed:(NSNotification*) note
{
    if (self.setting) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self update:self.setting];
        });
    }
}

- (void) update:(HLPSetting *)setting
{
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    
    self.setting = setting;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (self.setting.group) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(changed:)
                                                     name:HLPSettingChanged
                                                   object:self.setting.group];
    } else {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(changed:)
                                                     name:HLPSettingChanged
                                                   object:self.setting];
    }

    
    self.title.text = self.setting.label;
    self.title.adjustsFontSizeToFitWidth = YES;
    self.title.isAccessibilityElement = NO;
    self.title.textColor = self.setting.disabled ? [UIColor grayColor] : [UIColor blackColor];

    if (self.slider) {
        self.slider.enabled = !self.setting.disabled;
        self.slider.minimumValue = self.setting.min;
        self.slider.maximumValue = self.setting.max;
        if ([self.setting.currentValue isKindOfClass:[NSNumber class]]) {
            self.slider.value = [(NSNumber*)self.setting.currentValue floatValue];
        }
        self.slider.accessibilityLabel = self.setting.label;
        self.valueLabel.isAccessibilityElement = NO;
    }
    if (self.switchView) {
        self.switchView.enabled = !self.setting.disabled;
        self.switchView.on = [self.setting boolValue];
        self.switchView.accessibilityLabel = self.setting.label;
    }
    if (self.subtitle) {
        self.subtitle.textColor = self.setting.disabled ? [UIColor grayColor] : [UIColor blackColor];
        if (self.setting.type == NavCogSettingTypeOption) {
            self.accessoryType = [self.setting boolValue]?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone;
            self.subtitle.text = nil;
        } else if(self.setting.type == NavCogSettingTypeAction) {
            self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            self.subtitle.text = nil;
        } else {
            self.subtitle.text = [self.setting stringValue];
        }
    }
    if (self.textInput) {
        self.textInput.enabled = !self.setting.disabled;
        self.textInput.secureTextEntry = (setting.type == NavCogSettingTypePassInput);
        self.textInput.text = [self.setting stringValue];
        self.textInput.accessibilityLabel = self.setting.label;
    }
    [self updateView];
}

- (void) tapped:(id)sender
{
    if (self.setting.disabled) {
        return;
    }
    if (self.switchView) {
        [self.switchView setOn:!self.switchView.on animated:YES];
        [self switchChanged:self.switchView];
    }
    if (self.setting.type == NavCogSettingTypeOption) {
        [self.setting.group checkOption:self.setting];
    }
    if (self.setting.type == NavCogSettingTypeAction) {
        [self.delegate actionPerformed:self.setting];
    }
}

- (void) updateView
{
    [self.pickerView reloadAllComponents];
    [self.pickerView setAccessibilityLabel:self.setting.label];
    if ([self.setting selectedRow] >= 0) {
        [self.pickerView selectRow:[self.setting selectedRow] inComponent:0 animated:YES];
    }
    
    NSString*(^removeLastZeros)(NSString*) = ^(NSString* str) {
        NSString *temp = str;
        while([temp characterAtIndex:[temp length]-1] == '0') {
            temp = [temp substringToIndex:[temp length]-1];
        }
        return temp;
    };
    
    if (self.valueLabel) {
        if (self.setting.interval < 0.01) {
            self.valueLabel.text = [NSString stringWithFormat:@"%.3f", [self.setting floatValue]];
            self.slider.accessibilityValue = removeLastZeros(self.valueLabel.text);
        } else if (self.setting.interval < 0.1) {
            self.valueLabel.text = [NSString stringWithFormat:@"%.2f", [self.setting floatValue]];
            self.slider.accessibilityValue = removeLastZeros(self.valueLabel.text);
        } else if (self.setting.interval < 1) {
            self.valueLabel.text = [NSString stringWithFormat:@"%.1f", [self.setting floatValue]];
            self.slider.accessibilityValue = removeLastZeros(self.valueLabel.text);
        } else {
            self.valueLabel.text = [NSString stringWithFormat:@"%.0f", [self.setting floatValue]];
            self.slider.accessibilityValue = self.valueLabel.text;
        }

    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    // Configure the view for the selected state
}

- (IBAction)addItem:(id)sender {
    NSString *title = [NSString stringWithFormat:NSLocalizedStringFromTable(@"New %@",@"HLPSettingView",@"title for new option"), self.setting.label];
    NSString *message = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Input %@",@"HLPSettingView",@"prompt message for new option"), self.setting.label];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"Cancel",@"HLPSettingView",@"cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"OK",@"HLPSettingView",@"ok") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *colName = alert.textFields[0].text;
        NSObject *add = [self.setting checkValue:colName];
        
        if (add) {
            [self.setting addObject: add];
            [self.setting save];
            [self updateView];
        }
    }]];
    
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    
    [topController presentViewController:alert animated:YES completion:nil];
}

- (IBAction)removeItem:(id)sender {
    NSString *title = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Delete %@",@"HLPSettingView",@"title for delete alert"), self.setting.label];
    NSString *message = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Are you sure to delete %@？",@"HLPSettingView",@"confirmation message for delete alert"), self.setting.selectedValue];
    if ([self.setting numberOfRows] == 1) {
        message = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Could not delete",@"HLPSettingView",@"message when it cannot be deleted")];
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];

    
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"Cancel",@"HLPSettingView",@"cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"OK",@"HLPSettingView",@"ok") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self.setting removeSelected];
        [self.setting save];
        [self updateView];
    }]];
    
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    
    [topController presentViewController:alert animated:YES completion:nil];
}

- (IBAction)switchChanged:(id)sender {
    self.setting.currentValue = [self.setting checkValue:@(((UISwitch*) sender).on)];
    [self.setting save];
}

- (IBAction)valueChanged:(id)sender {
    if (sender == self.slider) {
        self.setting.currentValue = [self.setting checkValue:[NSNumber numberWithDouble:((UISlider*)sender).value]];
    }
    else if (sender == self.textInput) {
        self.setting.currentValue = [self.setting checkValue:self.textInput.text];
    }
    [self updateView];
    [self.setting save];
}

# pragma mark - picker view delegate

-(NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    if (self.pickerView) {
        return 1;
    }
    return 0;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return [self.setting numberOfRows];
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    [self.setting select:row];
    [self.setting save];
}

- (UIView *)pickerView:(UIPickerView *)pickerView
            viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view {
    UILabel *retval = (id)view;
    if (!retval) {
        retval= [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, [pickerView rowSizeForComponent:component].width, [pickerView rowSizeForComponent:component].height)];
    }
    
    retval.text = [self.setting titleForRow:row];
    if (self.setting.type == NavCogSettingTypeUUIDType) {
        retval.font = [UIFont systemFontOfSize:11];
    }
    
    return retval;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
    if (self.pickerView) {
        self.pickerView.dataSource = self;
        self.pickerView.delegate = self;
        [self updateView];
    }
}



@end
