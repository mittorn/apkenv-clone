#include "../apkenv.h"
#include <fcntl.h>
#include <linux/input.h>
#include <sys/select.h>
#include <sys/time.h>
int evdev_fd;
unsigned long ev_id=0,pev_id;
struct input_event *ev;
int x[10];
int y[10];
int finger=-1; //Last finger id
int pfinger=-1; //Previous finger value,needed to detect ACTION_UP
int state;
int screen_width,screen_height,max_x,max_y,min_x=0,min_y=0;
int actions[10]={1,1,1,1,1,1,1,1,1,1};//Actions to send
struct GlobalState * global;//pointer to GlobalState, needed to detect window position
void evdev_input_init()
{
global=get_global(); 
char*path=get_config("evdev_mt_path");
if(!path)path="/dev/event/input2";
char *tmpptr=get_config("screen_width");
if(!tmpptr||(screen_width=atoi(tmpptr))<1)screen_width=640;
tmpptr=get_config("screen_height");
if(!tmpptr||(screen_height=atoi(tmpptr))<1)screen_height=480;
tmpptr=get_config("evdev_mt_min_x");
if(tmpptr)min_x=atoi(tmpptr);
tmpptr=get_config("evdev_mt_min_y");
if(tmpptr)min_y=atoi(tmpptr);
max_x=screen_width,max_y=screen_height;
tmpptr=get_config("evdev_mt_max_x");
if(tmpptr)max_x=atoi(tmpptr);
tmpptr=get_config("evdev_mt_max_y");
if(tmpptr)max_y=atoi(tmpptr);
evdev_fd=open(path,O_RDONLY|O_NONBLOCK);
ev=malloc(16);
}
int evdev_input_update(struct SupportModule *module)
{
int c=read(evdev_fd,ev,16);
pev_id=ev_id;
if(c==16)ev_id++;
while(c==16)
{
//printf("_%d %d %d %d\n",ev->code,ev->value,pfinger,finger);
switch(ev->code){
case ABS_MT_POSITION_X:
x[finger]=ev->value;break;
case ABS_MT_POSITION_Y:
y[finger]=ev->value;break;
case ABS_MT_TRACKING_ID:finger=ev->value;break;
case 48:if(ev->value==0)finger=-1;break;
case 0:
    for(state=0;state<=finger;state++) {
	if(actions[state]!=1)
	    actions[state]=ACTION_MOVE;
	else actions[state]=0;
    }
    for(state=0;state<=pfinger-finger;state++)
	actions[finger+state+1]=ACTION_UP;
    pfinger=finger;
    break;
}
c=read(evdev_fd,ev,16);
}
int i;
for(i=0;i<=finger+state&&ev_id>pev_id;i++)
{
    module->input(module,actions[i],min_x+x[i]*screen_width/max_x-(*global).window_x,min_y+y[i]*screen_height/max_y-(*global).window_y,i);
    if(actions[i]==ACTION_UP&&state)state--;
//    printf("%d %d %d %d\n",actions[i],x[i],y[i],i);
}
state=0;
return 0;
}
