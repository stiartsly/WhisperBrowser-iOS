#import "SelfInfoViewController.h"
#import "LoginViewController.h"

@interface SelfInfoViewController ()
{
    NTWhisperUserInfo *selfInfo;
}
@end

@implementation SelfInfoViewController

- (instancetype)init
{
    return [super initWithStyle:UITableViewStyleGrouped];
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    self.navigationItem.title = @"我";

    self.tableView.rowHeight = 55.0f;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];

    selfInfo = [DeviceManager sharedManager].selfInfo;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selfInfoUpdated:) name:kNotificationSelfInfoUpdated object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)selfInfoUpdated:(NSNotification *)noti
{
    dispatch_async(dispatch_get_main_queue(), ^{
        selfInfo = noti.object;
        [self.tableView reloadData];
    });
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 3 : 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = nil;

    if (indexPath.section == 0) {
        cell = [tableView dequeueReusableCellWithIdentifier:@"TableViewCell"];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"TableViewCell"];
            //cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }

        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = @"名称";
                cell.detailTextLabel.text = selfInfo.name;
                break;

            case 1:
                cell.textLabel.text = @"电话";
                cell.detailTextLabel.text = selfInfo.phone;
                break;


            case 2:
                cell.textLabel.text = @"邮箱";
                cell.detailTextLabel.text = selfInfo.email;
                break;

            case 3:
                cell.textLabel.text = @"性别";
                cell.detailTextLabel.text = selfInfo.gender;
                break;

            case 4:
                cell.textLabel.text = @"地区";
                cell.detailTextLabel.text = selfInfo.region;
                break;

            case 5:
                cell.textLabel.text = @"签名";
                cell.detailTextLabel.text = selfInfo.briefDescription;
                break;

            default:
                break;
        }
    }
    else {
        cell = [tableView dequeueReusableCellWithIdentifier:@"LogoutCell"];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"LogoutCell"];
            cell.textLabel.text = @"登出";
            cell.textLabel.textColor = [UIColor redColor];
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
        }
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 1) {
        [[DeviceManager sharedManager] logout];

        LoginViewController * loginVC = [[LoginViewController alloc] initWithNibName:@"LoginViewController" bundle:nil];
        [UIApplication sharedApplication].keyWindow.rootViewController = loginVC;
    }
}

@end
