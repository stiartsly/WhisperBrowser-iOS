//
//  LoginViewController.m
//  WhisperWebBrowser
//
//  Created by suleyu on 2017/6/16.
//  Copyright © 2017年 kortide. All rights reserved.
//

#import "LoginViewController.h"

@interface LoginViewController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UIView *inputView;
@property (weak, nonatomic) IBOutlet UITextField *usernameTextField;
@property (weak, nonatomic) IBOutlet UITextField *passwordTextField;
@property (weak, nonatomic) IBOutlet UIButton *loginButton;

@end

@implementation LoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.

    self.inputView.layer.borderColor = UIColorFromRGB(0xDADADA).CGColor;
    self.inputView.layer.borderWidth  = 1.0f;
    self.inputView.layer.cornerRadius = 10.0f;
//
//    self.usernameTextField.text = @"chen.yu@kortide.com";
//    self.passwordTextField.text = @"password";
//    self.loginButton.enabled = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)hideKeyboard:(id)sender {
    [self.usernameTextField resignFirstResponder];
    [self.passwordTextField resignFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == self.usernameTextField) {
        [self.passwordTextField becomeFirstResponder];
    }
    else if (textField == self.passwordTextField) {
        [self.passwordTextField resignFirstResponder];
    }

    return YES;
}

- (IBAction)textFieldValueChanged:(UITextField *)sender {
    self.loginButton.enabled = self.usernameTextField.text.length > 0 && self.passwordTextField.text.length > 0;
}

- (IBAction)loginButtonClicked:(id)sender {
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [[DeviceManager sharedManager] login:self.usernameTextField.text password:self.passwordTextField.text completion:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSString *toast = (error.code == 0x81000007) ? @"用户名或密码错误" : @"登录失败";
                [MBProgressHUD showToast:toast inView:self.view duration:3 animated:YES];
            }
            else {
                UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
                [UIApplication sharedApplication].keyWindow.rootViewController = [storyboard instantiateInitialViewController];
            }
        });
    }];
}

@end
