//
//  DeviceSettingViewController.m
//  Whisper
//
//  Created by suleyu on 17/6/9.
//  Copyright © 2017年 Kortide. All rights reserved.
//

#import "DeviceSettingViewController.h"
#import "DeviceManager.h"

@interface DeviceSettingViewController () <UITextFieldDelegate>
{
    UITextField *serviceTextField;
}
@end

@implementation DeviceSettingViewController

- (instancetype)init
{
    return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self.tableView name:kNotificationDeviceListUpdated object:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"设备设置";
    
    self.tableView.rowHeight = 55.0f;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.separatorInset = UIEdgeInsetsZero;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reload) name:kNotificationDeviceListUpdated object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)reload
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![[DeviceManager sharedManager].devices containsObject:self.device]) {
            [self.navigationController popViewControllerAnimated:YES];
            return;
        }
        
        [self.tableView reloadData];
    });
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 4 : 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"reuseIdentifier"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"reuseIdentifier"];
        cell.textLabel.font = [UIFont systemFontOfSize:16.0f];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    // Configure the cell...
    if (indexPath.section == 0) {
        UITextField *textField = (UITextField*)cell.accessoryView;
        if (textField == nil) {
            CGFloat witdh = tableView.bounds.size.width - 120;
            if (witdh > 500) witdh = 500;
            textField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, witdh, 50)];
            textField.font = [UIFont systemFontOfSize:14.0f];
            textField.textAlignment = NSTextAlignmentRight;
            textField.delegate = self;
            cell.accessoryView = textField;
        }
        
        cell.textLabel.textColor = [UIColor blackColor];
        cell.textLabel.textAlignment = NSTextAlignmentLeft;
        
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = @"序列号";
                textField.text = self.device.deviceId;
                textField.textColor = UIColorFromRGB(0x666666);
                textField.enabled = NO;
                break;
                
            case 1:
                cell.textLabel.text = @"名称";
                textField.text = self.device.deviceName;
                textField.textColor = UIColorFromRGB(0x666666);
                textField.enabled = NO;
                break;

            case 2:
                cell.textLabel.text = @"协议";
                textField.textColor = [UIColor blackColor];
                textField.enabled = NO;
                if (self.device.protocol == WMWhisperTransportTypeTCP) {
                    textField.text = @"TCP";
                }
                else if (self.device.protocol == WMWhisperTransportTypeUDP) {
                    textField.text = @"UDP";
                }
                else {
                    textField.text = @"ICE";
                }
                break;
                
            case 3:
                cell.textLabel.text = @"服务";
                textField.text = self.device.service;
                textField.textColor = [UIColor blackColor];
                textField.keyboardType = UIKeyboardTypeNamePhonePad;
                textField.enabled = YES;
                serviceTextField = textField;
                break;
        }
    }
    else {
        cell.textLabel.text = @"删除设备";
        cell.textLabel.textColor = [UIColor redColor];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.accessoryView = nil;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [serviceTextField resignFirstResponder];
    
    if (indexPath.section == 1) {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        if (![[DeviceManager sharedManager] unPairDevice:self.device error:nil]) {
            hud.minSize = CGSizeZero;
            hud.mode = MBProgressHUDModeText;
            hud.labelText = @"删除失败";
            [hud hide:YES afterDelay:1];
        }
        else {
            [hud hide:YES];
            //[self.navigationController popViewControllerAnimated:YES];
        }
    }
    else if (indexPath.row == 2) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
        UIAlertAction *iceAction = [UIAlertAction actionWithTitle:@"ICE" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            self.device.protocol = WMWhisperTransportTypeICE;
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }];
        UIAlertAction *tcpAction = [UIAlertAction actionWithTitle:@"TCP" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            self.device.protocol = WMWhisperTransportTypeTCP;
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }];
        UIAlertAction *udpAction = [UIAlertAction actionWithTitle:@"UDP" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            self.device.protocol = WMWhisperTransportTypeUDP;
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }];
        [alertController addAction:cancelAction];
        [alertController addAction:iceAction];
        [alertController addAction:tcpAction];
        [alertController addAction:udpAction];

        UIPopoverPresentationController *popover = alertController.popoverPresentationController;
        if (popover != nil) {
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            popover.sourceView = cell;
            popover.sourceRect = cell.bounds;
            popover.permittedArrowDirections = UIPopoverArrowDirectionUp;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentViewController:alertController animated:YES completion:nil];
        });
    }
}

#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (![MBProgressHUD HUDForView:self.view]) {
        [textField resignFirstResponder];
    }
    return NO;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (textField == serviceTextField) {
        self.device.service = textField.text;
        if (self.device == [DeviceManager sharedManager].currentDevice) {
            [self.device connect];
        }
    }
    else if (textField.tag == 2) {
        if (![textField.text isEqualToString:self.device.deviceInfo.label]) {
            MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
            if (![[DeviceManager sharedManager] setDeviceLabel:self.device newLabel:textField.text error:nil]) {
                hud.minSize = CGSizeZero;
                hud.mode = MBProgressHUDModeText;
                hud.labelText = @"设置备注名失败";
                [hud hide:YES afterDelay:1];
                //textField.text = self.device.deviceName;
            }
            else {
                [hud hide:YES];
            }
        }
    }
}
@end
